# Cognito SSO Integration Guide

This document explains how to use the Cognito SSO integration that has been added to your application.

## Overview

The application now supports authentication via Amazon Cognito. Users must authenticate before accessing protected endpoints.

## Protected Endpoints

The following endpoints require authentication:

- `/auth-info` - Returns authentication information
- `/db-info` - Returns database connection information
- `/create` - Creates a users table in the database
- `/query` - Queries the users table
- `/add-user/{username}` - Adds a user to the database

## Public Endpoints

These endpoints do not require authentication:

- `/` - Welcome message
- `/health` - Health check
- `/auth/login` - Redirects to Cognito login page
- `/auth/callback` - Handles OAuth callback

## How to Authenticate

1. Visit `/auth/login` to get redirected to the Cognito login page
2. After successful login, you'll be redirected to `/auth/callback`
3. In a real application, you would exchange the authorization code for tokens
4. Use the ID token in the Authorization header for protected endpoints:
   ```
   Authorization: Bearer <your-id-token>
   ```

## Testing Authentication

You can test the authentication flow using curl:

```bash
# Access a protected endpoint (will fail without token)
curl http://localhost:8000/auth-info

# Access a protected endpoint with token
curl -H "Authorization: Bearer <your-id-token>" http://localhost:8000/auth-info
```

## Cognito Configuration

The Terraform scripts have created the following Cognito resources:

1. **User Pool** - Manages user registration and authentication
2. **User Pool Domain** - Provides a hosted UI for login
3. **User Pool Client** - Configures OAuth settings

## Customization

To customize the SSO behavior, you can modify the following variables in `variables.tf`:

- `cognito_callback_urls` - List of allowed callback URLs
- `cognito_logout_urls` - List of allowed logout URLs

## Troubleshooting

If you encounter issues with authentication:

1. Verify that the Cognito environment variables are correctly set in the ECS task
2. Check that the callback URLs match your application's URLs
3. Ensure that the user pool client is configured correctly
4. Check CloudWatch logs for any error messages