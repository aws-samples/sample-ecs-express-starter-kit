from fastapi import FastAPI, Depends, Request, HTTPException
from fastapi.responses import RedirectResponse
from starlette.exceptions import HTTPException as StarletteHTTPException
import os
import psycopg2
from psycopg2 import sql

from starlette.middleware.sessions import SessionMiddleware
from authlib.integrations.starlette_client import OAuth


app = FastAPI()

# Session middleware for storing auth state
app.add_middleware(
    SessionMiddleware, 
    secret_key=os.getenv("APP_SECRET_KEY"),
    https_only=os.getenv("ENV") == "production",
    same_site="lax"    
)

# Custom exception for auth redirect
class AuthRequired(Exception):
    pass

@app.exception_handler(AuthRequired)
async def auth_required_handler(request: Request, exc: AuthRequired):
    request.session["next"] = str(request.url)
    return RedirectResponse(url="/login", status_code=302)

# Auth0 configuration
oauth = OAuth()
oauth.register(
    name="auth0",
    client_id=os.getenv("AUTH0_CLIENT_ID"),
    client_secret=os.getenv("AUTH0_CLIENT_SECRET"),
    client_kwargs={"scope": "openid profile email"},
    server_metadata_url=f'https://{os.getenv("AUTH0_DOMAIN")}/.well-known/openid-configuration',
)

# Auth dependency - redirects to login if not authenticated
async def get_current_user(request: Request):
    user = request.session.get("user")
    if not user:
        raise AuthRequired()
    return user

@app.get("/login")
async def login(request: Request):
    redirect_uri = os.getenv("AUTH0_CALLBACK_URL", request.url_for("callback"))
    return await oauth.auth0.authorize_redirect(request, redirect_uri)

@app.get("/auth/callback")
async def callback(request: Request):
    token = await oauth.auth0.authorize_access_token(request)
    request.session["user"] = token.get("userinfo")
    # Redirect to original URL or home
    next_url = request.session.pop("next", "/")
    return RedirectResponse(url=next_url)

@app.get("/logout")
async def logout(request: Request):
    request.session.clear()
    auth0_domain = os.getenv("AUTH0_DOMAIN")
    client_id = os.getenv("AUTH0_CLIENT_ID")
    return_to = os.getenv("AUTH0_LOGOUT_URL", "http://127.0.0.1:8000")
    return RedirectResponse(
        url=f"https://{auth0_domain}/v2/logout?client_id={client_id}&returnTo={return_to}"
    )

# App Functions

@app.get("/")
def hello_world(user: dict = Depends(get_current_user)):
    # return {"message": "Hello, World!"}
    host = os.getenv('DB_LOCATION')
    user = os.getenv('DB_USER')
    password = os.getenv('DB_PASSWORD')
        
    return {"host": host, "user": user, "password": password}

@app.get("/create")
def create_table(user: dict = Depends(get_current_user)):
    host = os.getenv('DB_LOCATION')
    user = os.getenv('DB_USER')
    password = os.getenv('DB_PASSWORD')
    if not all([host, user, password]):
        return {"error": "DB_LOCATION, DB_USER, or DB_PASSWORD environment variables not set"}
    
    conn_string = f"postgresql://{user}:{password}@{host}:5432/postgres"
    
    try:
        conn = psycopg2.connect(conn_string)
        cursor = conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS users (
                user_name VARCHAR(255) NOT NULL
            );
        """)
        conn.commit()
        cursor.close()
        conn.close()
        return {"message": "Table 'users' created successfully"}
    except Exception as e:
        return {"error": str(e)}
    
@app.get("/query")
def query_table(user: dict = Depends(get_current_user)):
    host = os.getenv('DB_LOCATION')
    user = os.getenv('DB_USER')
    password = os.getenv('DB_PASSWORD')
    if not all([host, user, password]):
        return {"error": "DB_LOCATION, DB_USER, or DB_PASSWORD environment variables not set"}
    
    conn_string = f"postgresql://{user}:{password}@{host}:5432/postgres"
    
    try:
        conn = psycopg2.connect(conn_string)
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users;")
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
        return {"users": [row[0] for row in rows]}
    except Exception as e:
        return {"error": str(e)}


@app.get("/health")
def health_check():
    return {"message": "Healthy"}
