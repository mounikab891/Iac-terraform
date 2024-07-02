# Define AWS provider
provider "aws" {
  region = var.aws_region
}




########################################
########### ECR REPOSITORY ###########
########################################

resource "aws_ecr_repository" "mb_ecr_repository" {
  count        = var.create_new ? 1 : 0
  name                 = var.repo_name
  image_tag_mutability = "IMMUTABLE"

    encryption_configuration {
    encryption_type = "KMS"
    kms_key         = "****"
  }
  
  # Tags for ECR repository
  tags = var.tags

  image_scanning_configuration {
    scan_on_push = true
  }
}



##########################################
############# CW LOG GROUP ###############
##########################################

resource "aws_cloudwatch_log_group" "generic_log_group" {
  count        = var.create_new ? 1 : 0
  name  = "/ecs/${var.repo_name}"

  # Tags for CloudWatch log group
  tags = var.tags

}



#######################################
########### SERVICE TARGET GROUP ######
#######################################

resource "aws_lb_target_group" "mb_service_tg" {
  count        = var.create_new ? 1 : 0
  name      = var.repo_name
  port      = 80
  protocol  = "HTTP"
  vpc_id    = var.vpc_id

  # Tags for target group
  tags = var.tags
  
  health_check {
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }

  lifecycle {
    ignore_changes = [health_check]
  }
}


resource "aws_lb_listener_rule" "service_rule" {
  listener_arn = var.alb_internal_https_listener_arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mb_service_tg[0].arn
  }

  condition {
    host_header {
      values = ["${var.repo_name}.${var.domain_name}.in"]
    }
  }
}

provider "dns" {
  update {
    server = var.ns_name
  }
}

resource "aws_route53_record" "service_record" {
  zone_id         = var.zone_id
  name            = var.repo_name
  type            = "CNAME"
  records         = var.alb_dns_name
  ttl             = 300
}

#################################################
################ SSM PARAMETER ##################
#################################################

resource "aws_ssm_parameter" "service_parameter" {
  count        = var.create_new ? 1 : 0
  name     = "var.repo_name"
  type     = "SecureString"
  value    = "0.0.0.0"

  lifecycle {
    ignore_changes = [value]
  }
}



################################################
############## TASK DEFINITION #################
################################################

resource "aws_ecs_task_definition" "service_task" {
  count                = var.create_new ? 1 : 0
  family               = var.repo_name
  memory               = var.memory
  cpu                  = var.cpu
  task_role_arn        = var.TaskRoleArn
  execution_role_arn   = var.ExecutionRoleArn
  # Tags for task definition
  tags = var.tags
  container_definitions = <<TASK_DEFINITION
[
    {
      "image":"null",
      "name":"${var.repo_name}",
      "executionRoleArn": "${var.ExecutionRoleArn}",
      "taskRoleArn": "${var.TaskRoleArn}",
      "essential":true,
      "portMappings":[
        {
          "containerPort": 80,
          "hostPort": 0
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {	
          "awslogs-group": "${var.repo_name}",	
          "awslogs-region": "${var.aws_region}",	
          "awslogs-stream-prefix": "ecs"	
        }
      },
      "runtimePlatform": {
        "cpuArchitecture": "ARM64",
        "operatingSystemFamily": "LINUX"
      }
    }
]
TASK_DEFINITION
  
  lifecycle {
    ignore_changes = [container_definitions]
  }
}


################################################  
############## AWS ECS SERVICE #################
################################################

resource "aws_ecs_service" "service" {
  count        = var.create_new ? 1 : 0
  name             = var.repo_name
  cluster          = var.ecs_cluster_name
  task_definition  = aws_ecs_task_definition.service_task[0].arn
  desired_count    = var.desired_count 
  depends_on       = [aws_ecs_task_definition.service_task]

  # Tags for service 
  tags = var.tags

  load_balancer {
    target_group_arn = aws_lb_target_group.mb_service_tg[0].arn
    container_name   = var.repo_name
    container_port   = 80
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}
#####autoscaling#####

resource "aws_appautoscaling_target" "service-autoscale" {
  #for_each           = data.aws_ecs_service.service
  service_namespace  = "ecs"
  resource_id        = "service/${var.ecs_cluster_name}/${var.repo_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  #role_arn           = aws_iam_role.ecs-autoscale-role.arn
  min_capacity       =   var.desired_count
  max_capacity       = (var.desired_count)*2
}
##########################################################################################
##########CLOUDWATCH ALARM to monitor the cpu-scaleup utilization of a service (creating alarams)################################
########################################################################################
  resource "aws_cloudwatch_metric_alarm" "target-cpu-scaleup-alaram" {
  #for_each           = aws_appautoscaling_policy.target-cpu-scaleup_policy
  namespace         = "AWS/ECS"
  alarm_name        = "${var.ecs_cluster_name}/${var.repo_name}-cpu-scaleup"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = "80"
  evaluation_periods  = "5"
  metric_name         = "CPUUtilization"
  period              = "1800"
  statistic           = "Maximum"
  datapoints_to_alarm =  "5"
  dimensions = {
    
    ClusterName = "${var.ecs_cluster_name}"
    ServiceName = "${var.repo_name}"
  }
  alarm_description = "This metric monitors AWS/ECS/SERVICE CPU utilization"
  alarm_actions     = [aws_appautoscaling_policy.target-cpu-scaleup_policy.arn]

}

#########################################################################################
##########CLOUDWATCH ALARM to monitor the cpu-scaledown utilization of a service (creating alarams)################################
########################################################################################
  resource "aws_cloudwatch_metric_alarm" "target-cpu-scaledown-alaram" {
  #for_each           = aws_appautoscaling_policy.target-cpu-scaledown_policy
  namespace         = "AWS/ECS"
  alarm_name        = "${var.ecs_cluster_name}/${var.repo_name}-cpu-scaledown"
  comparison_operator = "LessThanOrEqualToThreshold"
  threshold           = "30"
  evaluation_periods  = "5"
  metric_name         = "CPUUtilization"
  period              = "1800"
  statistic           = "Maximum"
  datapoints_to_alarm =  "5"
  dimensions = {
    
    ClusterName = "${var.ecs_cluster_name}"
    ServiceName = "${var.repo_name}"
  }
  alarm_description = "This metric monitors AWS/ECS/SERVICE CPU utilization"
  alarm_actions     = [aws_appautoscaling_policy.target-cpu-scaledown_policy.arn]

}

######################################################################################
##CLOUDWATCH ALARM to monitor the memory-scaleup utilization of a service (creating alarams)##########
#########################################################################################
  resource "aws_cloudwatch_metric_alarm" "target-memory-scaleup-alaram" {
  #for_each           = aws_appautoscaling_policy.target-memory-scaleup_policy
  namespace         = "AWS/ECS"
  alarm_name        = "${var.ecs_cluster_name}/${var.repo_name}-memory-scaleup"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = "80"
  evaluation_periods  = "5"
  metric_name         = "MemoryUtilization"
  period              = "1800"
  statistic           = "Maximum"
  datapoints_to_alarm =  "5"
  dimensions = {
    
    ClusterName = "${var.ecs_cluster_name}"
    ServiceName = "${var.repo_name}"
  }
  alarm_description = "This metric monitors AWS/ECS/SERVICE Memory utilization"
  alarm_actions     = [aws_appautoscaling_policy.target-memory-scaleup_policy.arn]
}


################################################################################
######################## cpu-scale-up-policy ######################################
##################################################################################
resource "aws_appautoscaling_policy" "target-cpu-scaleup_policy" {
  #count              = length(var.target-cpu-scaleup_policy)
  #for_each           = aws_appautoscaling_target.service-autoscale
  name               = "${var.repo_name}-cpu_scaleup"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.service-autoscale.resource_id
  scalable_dimension = aws_appautoscaling_target.service-autoscale.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service-autoscale.service_namespace
    
    step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 300
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
      
    }
    
  }
 
}
################################################################################
######################## cpu-scale-down-policy ######################################
##################################################################################
resource "aws_appautoscaling_policy" "target-cpu-scaledown_policy" {
  #for_each           = aws_appautoscaling_target.service-autoscale
  name               = "${var.repo_name}-cpu_scaledown"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.service-autoscale.resource_id
  scalable_dimension = aws_appautoscaling_target.service-autoscale.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service-autoscale.service_namespace
    
    step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 300
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
      
    }
    
  }
 
}


################################################################################
######################## memory-scale-up-policy ######################################
################################################################################
resource "aws_appautoscaling_policy" "target-memory-scaleup_policy" {
  #for_each           = aws_appautoscaling_target.service-autoscale
  name               = "${var.repo_name}-memory_scaleup"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.service-autoscale.resource_id
  scalable_dimension = aws_appautoscaling_target.service-autoscale.scalable_dimension
  service_namespace  = aws_appautoscaling_target.service-autoscale.service_namespace
    step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 300
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
      }
  }

  
}

resource "aws_cloudwatch_metric_alarm" "task_count_zero" {
  alarm_name          = "${var.ecs_cluster_name}/${var.repo_name}/Task-Count-Zero"
  alarm_description   = "Alarm for RunningTaskCount in ECS service ${var.repo_name}"
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  statistic           = "Maximum"
  period              = 300
  threshold           = 0
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  alarm_actions       = [var.sns_arn]

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.repo_name
  }
}

resource "aws_cloudwatch_metric_alarm" "max_tasks_alarm" {
  alarm_name          = "${var.ecs_cluster_name}/${var.repo_name}-Using-MaxRunningTaskCount"
  alarm_description   = "Alarm for RunningTaskCount in ECS service ${var.repo_name}"
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  statistic           = "Maximum"
  period              = 300
  threshold           = aws_appautoscaling_target.service-autoscale.max_capacity
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  alarm_actions       = [var.sns_arn]

  dimensions = {
     ClusterName = var.ecs_cluster_name
     ServiceName = var.repo_name
  }
}
resource "aws_cloudwatch_composite_alarm" "composite_alarm" {
  alarm_name          = "${var.ecs_cluster_name}/${var.repo_name}/composite_alarm"
  alarm_description   = "Composite Alarm for CPU Utilization and Running Task Count in ECS service ${var.repo_name}"
  alarm_actions       = [var.sns_arn]
  alarm_rule          = "ALARM(${aws_cloudwatch_metric_alarm.max_tasks_alarm.arn}) AND ALARM(${aws_cloudwatch_metric_alarm.target-cpu-scaleup-alaram.arn})"
}
