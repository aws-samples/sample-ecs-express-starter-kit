

resource "aws_ecs_cluster" "example"{
  name = local.common_tags["Name"]
}

resource "aws_ecs_express_gateway_service" "example" {
  cluster = aws_ecs_cluster.example.name
  execution_role_arn      = aws_iam_role.execution.arn
  infrastructure_role_arn = aws_iam_role.infrastructure.arn
  task_role_arn          = aws_iam_role.task.arn
  health_check_path       = "/health"
  wait_for_steady_state = false
  cpu = "2048"
  memory = "4096"
  

  network_configuration {
    subnets             = aws_subnet.public[*].id
    security_groups = [aws_security_group.ecs.id]

  }



  primary_container {
    image          = var.app_image
    container_port = var.container_port
    # command        = ["./start.sh"]
    
    
    aws_logs_configuration {
      log_stream_prefix = "ecs-express"
      log_group = local.common_tags["Name"]
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

    # repository_credentials {
    #   credentials_parameter = "arn:aws:secretsmanager:XXXX"
    # }

    secret {
      name       = "DB_PASSWORD"
      value_from = aws_secretsmanager_secret.db_password.arn
    }

    # # Cognito SSO configuration
    # environment {
    #   name  = "COGNITO_USER_POOL_ID"
    #   value = aws_cognito_user_pool.main.id
    # }

    # environment {
    #   name  = "COGNITO_CLIENT_ID"
    #   value = aws_cognito_user_pool_client.main.id
    # }

    # environment {
    #   name  = "COGNITO_DOMAIN"
    #   value = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.region}.amazoncognito.com"
    # }

    # environment {
    #   name  = "COGNITO_REGION"
    #   value = var.region
    # }
  }

  tags = local.common_tags
}