# Amazon Cognito User Pool for SSO Authentication

# resource "aws_cognito_user_pool" "main" {
#   name = "${local.common_tags["Name"]}-user-pool"

#   # Password policy
#   password_policy {
#     minimum_length    = 8
#     require_lowercase = true
#     require_numbers   = true
#     require_symbols   = true
#     require_uppercase = true
#   }

#   # Account recovery
#   account_recovery_setting {
#     recovery_mechanism {
#       name     = "verified_email"
#       priority = 1
#     }
#   }

#   # Auto-verified attributes
#   auto_verified_attributes = ["email"]

#   # Username configuration
#   username_attributes = ["email"]
  
#   username_configuration {
#     case_sensitive = false
#   }

#   # Schema attributes
#   schema {
#     name                     = "email"
#     attribute_data_type      = "String"
#     required                 = true
#     mutable                  = true
#     string_attribute_constraints {
#       min_length = 1
#       max_length = 256
#     }
#   }

#   schema {
#     name                     = "name"
#     attribute_data_type      = "String"
#     required                 = false
#     mutable                  = true
#     string_attribute_constraints {
#       min_length = 1
#       max_length = 256
#     }
#   }

#   # Email configuration (using Cognito default)
#   email_configuration {
#     email_sending_account = "COGNITO_DEFAULT"
#   }

#   # MFA configuration (optional - can be enabled)
#   mfa_configuration = "OFF"

#   # Allow admin to create users
#   admin_create_user_config {
#     allow_admin_create_user_only = false
#   }

#   tags = local.common_tags
# }

# # Test user for the application
# resource "random_password" "test_user_password" {
#   length           = 16
#   special          = true
#   override_special = "!@#$%"
#   min_lower        = 2
#   min_upper        = 2
#   min_numeric      = 2
#   min_special      = 2
# }

# resource "aws_cognito_user" "test_user" {
#   user_pool_id = aws_cognito_user_pool.main.id
#   username     = var.test_user_email

#   attributes = {
#     email          = var.test_user_email
#     email_verified = true
#   }

#   temporary_password = random_password.test_user_password.result
# }

# # Cognito User Pool Domain
# resource "aws_cognito_user_pool_domain" "main" {
#   domain       = "${local.common_tags["Name"]}-${random_string.cognito_domain_suffix.result}"
#   user_pool_id = aws_cognito_user_pool.main.id
# }

# resource "random_string" "cognito_domain_suffix" {
#   length  = 8
#   special = false
#   upper   = false
# }

# # Initial Cognito User Pool Client (created with placeholder URLs)
# resource "aws_cognito_user_pool_client" "main" {
#   name         = "${local.common_tags["Name"]}-client"
#   user_pool_id = aws_cognito_user_pool.main.id

#   # OAuth configuration
#   allowed_oauth_flows                  = ["code"]
#   allowed_oauth_flows_user_pool_client = true
#   allowed_oauth_scopes                 = ["email", "openid", "profile"]
  
#   # Initial callback URLs - will be updated after ECS deployment
#   callback_urls = var.additional_callback_urls
#   logout_urls   = var.additional_logout_urls

#   # Supported identity providers
#   supported_identity_providers = ["COGNITO"]

#   # Token validity
#   access_token_validity  = 1
#   id_token_validity      = 1
#   refresh_token_validity = 30

#   token_validity_units {
#     access_token  = "hours"
#     id_token      = "hours"
#     refresh_token = "days"
#   }

#   # Security settings
#   generate_secret                      = false
#   prevent_user_existence_errors        = "ENABLED"
#   enable_token_revocation              = true
#   enable_propagate_additional_user_context_data = false

#   explicit_auth_flows = [
#     "ALLOW_REFRESH_TOKEN_AUTH",
#     "ALLOW_USER_SRP_AUTH"
#   ]

#   # Ignore changes to callback_urls since we update them via CLI after ECS deploys
#   lifecycle {
#     ignore_changes = [callback_urls, logout_urls]
#   }
# }

# # Update Cognito client with ECS endpoint after service is created
# resource "null_resource" "update_cognito_urls" {
#   depends_on = [
#     aws_ecs_express_gateway_service.example,
#     aws_cognito_user_pool_client.main
#   ]

#   triggers = {
#     # Use the service name and cluster as triggers
#     service_name = aws_ecs_express_gateway_service.example.service_name
#     cluster      = aws_ecs_express_gateway_service.example.service_name
#   }

#   provisioner "local-exec" {
#     command = <<-EOT
#       echo "Fetching ECS Express endpoint..."
      
#       # List express gateway services to get the ARN
#       SERVICE_ARN=$(aws ecs list-express-gateway-services \
#         --cluster ${aws_ecs_cluster.example.name} \
#         --region ${var.region} \
#         --query 'expressGatewayServices[0].serviceArn' \
#         --output text)
      
#       echo "Service ARN: $SERVICE_ARN"
      
#       # Get the endpoint from the ECS Express Gateway Service
#       ENDPOINT=$(aws ecs describe-express-gateway-service \
#         --service-arn "$SERVICE_ARN" \
#         --region ${var.region} \
#         --query 'expressGatewayService.activeServiceRevision.ingressPaths[0].endpoint' \
#         --output text)
      
#       echo "ECS Express endpoint: $ENDPOINT"
      
#       # Update Cognito client with the real endpoint
#       aws cognito-idp update-user-pool-client \
#         --user-pool-id ${aws_cognito_user_pool.main.id} \
#         --client-id ${aws_cognito_user_pool_client.main.id} \
#         --callback-urls "http://$ENDPOINT/auth/callback" ${join(" ", [for url in var.additional_callback_urls : "\"${url}\""])} \
#         --logout-urls "http://$ENDPOINT/logout" "http://$ENDPOINT" ${join(" ", [for url in var.additional_logout_urls : "\"${url}\""])} \
#         --allowed-o-auth-flows code \
#         --allowed-o-auth-scopes email openid profile \
#         --supported-identity-providers COGNITO \
#         --allowed-o-auth-flows-user-pool-client \
#         --region ${var.region}
      
#       echo "Cognito client updated successfully with endpoint: $ENDPOINT"
#     EOT
#   }
# }

# # Outputs for application configuration
# output "cognito_user_pool_id" {
#   description = "Cognito User Pool ID"
#   value       = aws_cognito_user_pool.main.id
# }

# output "cognito_user_pool_client_id" {
#   description = "Cognito User Pool Client ID"
#   value       = aws_cognito_user_pool_client.main.id
# }

# output "cognito_domain" {
#   description = "Cognito hosted UI domain"
#   value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.region}.amazoncognito.com"
# }

