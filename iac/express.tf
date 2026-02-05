

resource "aws_ecs_cluster" "example" {
  name = local.common_tags["Name"]
}

resource "aws_ecs_express_gateway_service" "example" {
  cluster                 = aws_ecs_cluster.example.name
  execution_role_arn      = aws_iam_role.execution.arn
  infrastructure_role_arn = aws_iam_role.infrastructure.arn
  task_role_arn           = aws_iam_role.task.arn
  health_check_path       = "/health"
  wait_for_steady_state   = false
  cpu                     = "2048"
  memory                  = "4096"


  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.ecs.id]

  }



  primary_container {
    image          = var.app_image
    container_port = var.container_port
    # command        = ["./start.sh"]


    aws_logs_configuration {
      log_stream_prefix = "ecs-express"
      log_group         = local.common_tags["Name"]
    }

    environment {
      name  = "ENV"
      value = "production"
    }


    environment {
      name  = "DB_USER"
      value = var.db_username
    }

    environment {
      name  = "DB_LOCATION"
      value = aws_rds_cluster.aurora_serverless.endpoint
    }

    environment {
      name  = "AUTH0_DOMAIN"
      value = var.auth0_domain # e.g., "your-tenant.auth0.com"
    }

    environment {
      name  = "AUTH0_CLIENT_ID"
      value = var.auth0_client_id
    }

    environment {
      name  = "AUTH0_CLIENT_SECRET"
      value = var.auth0_client_secret # Consider using Secrets Manager
    }

    environment {
      name  = "AUTH0_CALLBACK_URL"
      value = "https://your-app-url/auth/callback"
    }

    environment {
      name  = "AUTH0_LOGOUT_URL"
      value = "https://your-app-url"
    }

    environment {
      name  = "APP_SECRET_KEY"
      value = var.APP_SECRET_GEN
      # value = random_password.app_secret.result
    }

    # repository_credentials {
    #   credentials_parameter = "arn:aws:secretsmanager:XXXX"
    # }

    secret {
      name       = "DB_PASSWORD"
      value_from = aws_secretsmanager_secret.db_password.arn
    }


  }

  lifecycle {
    ignore_changes = [
      primary_container[0].environment,
      primary_container[0].command
    ]
  }

  # depends_on = [
  #   aws_subnet.public,
  #   aws_internet_gateway.main
  # ]  

  tags = local.common_tags
}

locals {
  app_endpoint = aws_ecs_express_gateway_service.example.ingress_paths[0].endpoint
}

output "ingress_paths" {
  description = "ECS Express Gateway Service endpoint URL"
  value       = aws_ecs_express_gateway_service.example.ingress_paths[0].endpoint
}

output "service_arns" {
  description = "ECS Express Gateway Service ARN"
  value       = aws_ecs_express_gateway_service.example.service_arn
}

output "update_auth0_urls" {
  value = join("", [
    "aws ecs update-express-gateway-service ",
    "--service-arn ${aws_ecs_express_gateway_service.example.service_arn} ",
    "--region ${var.region} ",
    "--primary-container 'image=${local.ecr_image_uri},environment=[{name=ENV,value=production},{name=AUTH0_DOMAIN,value=${var.auth0_domain}},{name=AUTH0_CLIENT_ID,value=${var.auth0_client_id}},{name=APP_SECRET_KEY,value=${var.APP_SECRET_GEN}},{name=AUTH0_CLIENT_SECRET,value=${var.auth0_client_secret}},{name=AUTH0_LOGOUT_URL,value=https://${local.app_endpoint}},{name=AUTH0_CALLBACK_URL,value=https://${local.app_endpoint}/auth/callback},{name=DB_USER,value=${var.db_username}},{name=DB_LOCATION,value=${aws_rds_cluster.aurora_serverless.endpoint}}]'",
  ])
  sensitive = true
}

# output "update_auth0_urls" {
#     value = join("", [
#              "aws ecs update-express-gateway-service ", 
#              "--service-arn ${aws_ecs_express_gateway_service.example.service_arn} ",
#              "--region ${var.region} ",
#              "--primary-container 'image=${var.app_image},environment=[{name=ENV,value=production},{name=AUTH0_DOMAIN,value=${var.auth0_domain}},{name=AUTH0_CLIENT_ID,value=${var.auth0_client_id}},{name=APP_SECRET_KEY,value=${var.APP_SECRET_GEN}},{name=AUTH0_CLIENT_SECRET,value=${var.auth0_client_secret}},{name=AUTH0_LOGOUT_URL,value=https://${local.app_endpoint}},{name=AUTH0_CALLBACK_URL,value=https://${local.app_endpoint}/auth/callback},{name=DB_USER,value=${var.db_username}},{name=DB_LOCATION,value=${aws_rds_cluster.aurora_serverless.endpoint}}]'",
#             ])
#     sensitive= true


# }


# Uncomment to auto-update Auth0 URLs during terraform apply:
# resource "null_resource" "update_auth0_urls" {
#   depends_on = [aws_ecs_express_gateway_service.example]
#
#   triggers = {
#     service_arn = aws_ecs_express_gateway_service.example.service_arn
#   }
#
#   provisioner "local-exec" {
#     command = <<-EOT
#       echo "Updating ECS service with endpoint: ${aws_ecs_express_gateway_service.example.ingress_paths[0].endpoint}"
#       aws ecs update-express-gateway-service \
#         --service-arn ${aws_ecs_express_gateway_service.example.service_arn} \
#         --region ${var.region} \
#         --primary-container "image=${var.app_image}, environment=[{name=AUTH0_DOMAIN, value=${var.auth0_domain}}, {name=AUTH0_CLIENT_ID, value=${var.auth0_client_id}}, {name=APP_SECRET_KEY, value=${var.APP_SECRET_GEN}}, {name=AUTH0_CLIENT_SECRET, value=${var.auth0_client_secret}}, {name=AUTH0_LOGOUT_URL,value=http://${local.app_endpoint}},{name=AUTH0_CALLBACK_URL,value=http://${local.app_endpoint}/auth/callback}]"
#       echo "Updated the AUTH URLs. Wait for it to get deployed..."
#     EOT
#   }
# }

# Or run: ../iac-cli/update-auth0-urls.sh after terraform apply
