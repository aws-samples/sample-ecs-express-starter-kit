import os
from fastapi import APIRouter, Request, HTTPException
from fastapi.responses import RedirectResponse
from authlib.integrations.starlette_client import OAuth



# Create a router to hold auth routes
router = APIRouter()

# Clean domain to prevent double https:// issues
auth0_domain = os.getenv("AUTH0_DOMAIN", "").replace("https://", "").rstrip("/")

# Auth0 configuration
oauth = OAuth()
oauth.register(
    name="auth0",
    client_id=os.getenv("AUTH0_CLIENT_ID"),
    client_secret=os.getenv("AUTH0_CLIENT_SECRET"),
    client_kwargs={"scope": "openid profile email"},
    server_metadata_url=f'https://{auth0_domain}/.well-known/openid-configuration',
)

class AuthRequired(Exception):
    """Custom exception raised when user is not authenticated."""
    pass

def register_auth_exception_handler(app):
    """Helper to register the exception handler on the main app."""
    @app.exception_handler(AuthRequired)
    async def auth_required_handler(request: Request, exc: AuthRequired):
        request.session["next"] = str(request.url)
        return RedirectResponse(url="/login", status_code=302)

async def get_current_user(request: Request):
    """Dependency to get current user or raise AuthRequired."""
    user = request.session.get("user")
    if not user:
        raise AuthRequired()
    return user

@router.get("/login")
async def login(request: Request):
    # Calculate callback URL, handling potential proxy issues
    redirect_uri = os.getenv("AUTH0_CALLBACK_URL")
    if not redirect_uri:
        redirect_uri = str(request.url_for("callback"))
    
    # Force HTTPS in production if behind a proxy
    if os.getenv("ENV") == "production" and redirect_uri.startswith("http://"):
        redirect_uri = redirect_uri.replace("http://", "https://", 1)

    return await oauth.auth0.authorize_redirect(request, redirect_uri)

@router.get("/auth/callback", name="callback")
async def callback(request: Request):
    token = await oauth.auth0.authorize_access_token(request)
    request.session["user"] = token.get("userinfo")
    next_url = request.session.pop("next", "/")
    return RedirectResponse(url=next_url)

@router.get("/logout")
async def logout(request: Request):
    request.session.clear()
    client_id = os.getenv("AUTH0_CLIENT_ID")
    # Default to base URL if LOGOUT_URL not set
    return_to = os.getenv("AUTH0_LOGOUT_URL", str(request.base_url))
    
    return RedirectResponse(
        url=f"https://{auth0_domain}/v2/logout?client_id={client_id}&returnTo={return_to}"
    )