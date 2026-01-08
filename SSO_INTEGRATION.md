# This app use Okta Auth0 to secure. Please create a free Okta account auth0 before hand.

Auth0 Dashboard Setup
In your Auth0 dashboard:

Create a new "Regular Web Application"
Set Allowed Callback URLs: https://your-ecs-endpoint/auth/callback
Set Allowed Logout URLs: https://your-ecs-endpoint
Copy the Domain, Client ID, and Client Secret


Use this code to generate APP_SECRET or use the cloude services
```bash
python -c "import secrets; print(secrets.token_hex(32))"
```