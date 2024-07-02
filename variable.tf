####################################
######### GENERIC VARIABLES ########
####################################

variable "account" {
  type        = string
  description = "AWS Account Number"
  default = "***"
}

variable "desired_count" {
  description = "Desired count of ECS service"
  type        = number
  #default = 2
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "***"
}

variable "domain_name" {
  type        = string
  description = "The domain name that we will use throughtout the infrastructure"
  default     = "****"
}

# variable "environment" {
#   type        = string
#   description = "The environment name for an application to deploy"
#   default = "**"

# }

# variable "team" {
#   type        = string
#   description = "The team name used for tagging"
#   default     = "***"
# }

# variable "project" {
#   type        = string
#   description = "The project name that will be throughtout the infrastructure"
#   default     = "**"
# }

variable "vpc_id" {
  type        = string
  description = "vpc_id to create resources inside the VPC"
  default = "****"
}

#variable "subnets" {
 # type        = list(string)
 # description = "private subnets IDs to deploy resources"
 # default     = ["***", "***"]


#}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate arn of mbstg.in domain for ALB's"
  default     = "****"

}

variable "alb_dns_name" {
  type        = list(string)
  description = "DNS name of internal ALB"
  default     = ["****"]

}

variable "zone_id" {
  type        = string
  description = "Name of the route53 zone"
  default     = "***"
}

variable "ns_name" {
  type        = string
  description = "Name of the NAME SERVER record of mbstg.in domain"
  default     = "****"
}

variable "private_subnets" {
  type        = list(string)
  description = "private subnet ids of docsapptest-staging-vpc"
  default     = ["****", "***"]
}

variable "alb_internal_https_listener_arn" {
  type        = string
  description = "ARN of the internal ALB's HTTPS listener"
  default     = "****"
}

variable "ExecutionRoleArn" {
  type        = string
  description = "ARN of the ExecutionRole"
  default     = "***"
}

variable "TaskRoleArn" {
  type        = string
  description = "ARN of the TaskRole"
  default     = "***"
}

# Define variable for tags
variable "tags" {
  description = "A map of tags to apply to all resources"
  type        = map(string)
  default     = {
    Environment = "***"
    Application = "**"
  }
}

variable "repo_name" {
  type        = string
  description = "reponame"
  #default     = "***"
}

variable "ecs_cluster_name" {
  type        = string
  description = "reponame"
  default     = "***"
}
# variable "service_name" {
#   type        = string
#   description = "reponame"
#   default     = "***"

# }
variable "cluster_arn" {
  type        = string
  description = "reponame"
  default     = "****"
}

variable "create_new" {
  description = "Flag to indicate whether to create a new ECS service"
  type        = bool
  default     = true  # Set default value as needed
}

variable "cpu" {
  type        = number
  description = "cpu"
}

variable "memory" {
  type        = number
  description = "memory"
}
variable "sns_arn" {
  type = string
  default = "*******"
}

