
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
  default     = "public.ecr.aws/p7b6k2h9/mod-app:0.0.6"
  # default     = "public.ecr.aws/p7b6k2h9/mod-app:0.1.1" with cognito
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

# Cognito SSO Variables
# Additional callback/logout URLs (e.g., for local development)
variable "additional_callback_urls" {
  description = "Additional callback URLs for Cognito OAuth (e.g., localhost for development)"
  type        = list(string)
  default     = ["http://localhost:8000/auth/callback"]
}

variable "additional_logout_urls" {
  description = "Additional logout URLs for Cognito (e.g., localhost for development)"
  type        = list(string)
  default     = ["http://localhost:8000/logout", "http://localhost:8000"]
}


variable "test_user_email" {
  default = "test@example.com" 
}