
# data "aws_vpc" "default" {
#   default = true
# }

# variable "vpc_id" {
#   description = "VPC id for DB and ECS"
#   type        = string
#   default     = ""
# }

variable "region" {
  description = "AWS region"
  default     = "ap-southeast-2"
}

variable "environment" {
  description = "Deployment environment"
  default     = "production"
}

locals {
  common_tags = {
    express-mode = "demo"
    Name         = "express-mode-demo"
    Environment  = var.environment
  }
  # vpc_id = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default.id
}




variable "app_image" {
  description = "Container image for primary container"
  # default     = "public.ecr.aws/p7b6k2h9/mod-app:0.0.6" no ss0
  default     = "public.ecr.aws/p7b6k2h9/mod-app:0.1.4" # with auth0
}

variable "container_port" {
  description = "Primary container port"
  default     = 8000
}

variable "db_username" {
  description = "DB master username"
  default     = "app"
}

variable "db_name" {
  description = "Database name"
  default     = "appdb"
}

variable "password_length" {
  description = "Length of generated DB password"
  default     = 20
}

# variable "vpc_id" {
#   description = "VPC id for DB and ECS"
#   type        = string
#   default     = ""
# }

# variable "private_subnet_ids" {
#   description = "List of private subnet ids for Aurora"
#   type        = list(string)
#   default     = []
# }

# Auth0
variable "auth0_domain" {
  description = "Auth0 tenant domain (e.g., your-tenant.auth0.com)"
  type        = string
}

variable "auth0_client_id" {
  description = "Auth0 application client ID"
  type        = string
}

variable "auth0_client_secret" {
  description = "Auth0 application client secret"
  type        = string
  sensitive   = true
}

variable "APP_SECRET_GEN" {
  description = "Generated APP_SECRET"
  type        = string
  sensitive   = true
}
