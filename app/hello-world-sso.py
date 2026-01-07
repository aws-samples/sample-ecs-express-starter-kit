from fastapi import FastAPI, Depends, HTTPException, status, Request, Query
from fastapi.responses import RedirectResponse, HTMLResponse
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import os
import psycopg2
from psycopg2 import sql
import requests
from jose import jwt, JWTError
from typing import Optional
from urllib.parse import urlencode

app = FastAPI()

# Cognito configuration from environment variables
COGNITO_USER_POOL_ID = os.getenv("COGNITO_USER_POOL_ID")
COGNITO_CLIENT_ID = os.getenv("COGNITO_CLIENT_ID")
COGNITO_REGION = os.getenv("COGNITO_REGION", "ap-southeast-2")
COGNITO_DOMAIN = os.getenv("COGNITO_DOMAIN")
APP_BASE_URL = os.getenv("APP_BASE_URL", "http://localhost:8000")

# Construct the JWKS URL for verifying tokens
COGNITO_JWKS_URL = f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}/.well-known/jwks.json"

# Security scheme (optional for browser-based auth)
security = HTTPBearer(auto_error=False)

class CognitoAuth:
    def __init__(self):
        self.jwks = None
    
    def get_jwks(self):
        """Fetch JWKS from Cognito"""
        if not self.jwks:
            try:
                response = requests.get(COGNITO_JWKS_URL)
                self.jwks = response.json()
            except Exception as e:
                print(f"Error fetching JWKS: {e}")
                return None
        return self.jwks
    
    def verify_token(self, token: str):
        """Verify JWT token"""
        try:
            headers = jwt.get_unverified_headers(token)
            kid = headers['kid']
            
            jwks = self.get_jwks()
            if not jwks:
                return None
                
            key = None
            for k in jwks["keys"]:
                if k["kid"] == kid:
                    key = k
                    break
            
            if not key:
                return None
            
            payload = jwt.decode(
                token,
                key,
                algorithms=["RS256"],
                audience=COGNITO_CLIENT_ID,
                issuer=f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}",
                options={"verify_at_hash": False}
            )
            return payload
        except JWTError as e:
            print(f"JWT Error: {e}")
            return None

cognito_auth = CognitoAuth()

def get_base_url(request: Request) -> str:
    """Get the base URL from request headers"""
    host = request.headers.get("host", "localhost:8000")
    scheme = request.headers.get("x-forwarded-proto", "http")
    return f"{scheme}://{host}"

def get_login_url(request: Request) -> str:
    """Generate Cognito login URL"""
    base_url = get_base_url(request)
    callback_url = f"{base_url}/auth/callback"
    params = {
        "response_type": "code",
        "client_id": COGNITO_CLIENT_ID,
        "redirect_uri": callback_url,
        "scope": "email openid profile"
    }
    return f"{COGNITO_DOMAIN}/login?{urlencode(params)}"


def get_db_connection():
    """Helper function to get database connection"""
    host = os.getenv('DB_LOCATION')
    user = os.getenv('DB_USER')
    password = os.getenv('DB_PASSWORD')
    
    if not all([host, user, password]):
        raise HTTPException(status_code=500, detail="Database environment variables not set")
    
    conn_string = f"postgresql://{user}:{password}@{host}:5432/postgres"
    return psycopg2.connect(conn_string)

# Store tokens in memory (use Redis/session store in production)
token_store = {}

@app.get("/")
def home(request: Request):
    """Home page with login link"""
    session_id = request.cookies.get("session_id")
    user = token_store.get(session_id) if session_id else None
    
    if user:
        return HTMLResponse(f"""
        <html>
        <body>
            <h1>Welcome to Express Mode Demo</h1>
            <p>Logged in as: {user.get('email', 'Unknown')}</p>
            <ul>
                <li><a href="/protected">Protected Page</a></li>
                <li><a href="/db-info">Database Info</a></li>
                <li><a href="/auth/logout">Logout</a></li>
            </ul>
        </body>
        </html>
        """)
    
    login_url = get_login_url(request)
    return HTMLResponse(f"""
    <html>
    <body>
        <h1>Welcome to Express Mode Demo</h1>
        <p>Please login to access protected resources.</p>
        <a href="{login_url}"><button>Login with Cognito</button></a>
    </body>
    </html>
    """)

@app.get("/health")
def health_check():
    """Health check endpoint"""
    return {"message": "Healthy"}

@app.get("/auth/login")
def login_redirect(request: Request):
    """Redirect to Cognito login page"""
    login_url = get_login_url(request)
    return RedirectResponse(url=login_url)

@app.get("/auth/callback")
def auth_callback(request: Request, code: str = Query(None), error: str = Query(None)):
    """Handle OAuth callback - exchange code for tokens"""
    if error:
        return HTMLResponse(f"<h1>Authentication Error</h1><p>{error}</p><a href='/'>Go Home</a>")
    
    if not code:
        return HTMLResponse("<h1>No authorization code received</h1><a href='/'>Go Home</a>")
    
    base_url = get_base_url(request)
    callback_url = f"{base_url}/auth/callback"
    
    # Exchange code for tokens
    token_url = f"{COGNITO_DOMAIN}/oauth2/token"
    data = {
        "grant_type": "authorization_code",
        "client_id": COGNITO_CLIENT_ID,
        "code": code,
        "redirect_uri": callback_url
    }
    
    try:
        response = requests.post(token_url, data=data, headers={"Content-Type": "application/x-www-form-urlencoded"})
        tokens = response.json()
        
        if "error" in tokens:
            return HTMLResponse(f"<h1>Token Error</h1><p>{tokens.get('error_description', tokens['error'])}</p><a href='/'>Go Home</a>")
        
        # Verify and decode the ID token
        id_token = tokens.get("id_token")
        user_info = cognito_auth.verify_token(id_token)
        
        if not user_info:
            return HTMLResponse("<h1>Token verification failed</h1><a href='/'>Go Home</a>")
        
        # Create session
        import uuid
        session_id = str(uuid.uuid4())
        token_store[session_id] = {
            "email": user_info.get("email"),
            "sub": user_info.get("sub"),
            "id_token": id_token,
            "access_token": tokens.get("access_token")
        }
        
        response = RedirectResponse(url="/", status_code=302)
        response.set_cookie(key="session_id", value=session_id, httponly=True, max_age=3600)
        return response
        
    except Exception as e:
        return HTMLResponse(f"<h1>Error exchanging code</h1><p>{str(e)}</p><a href='/'>Go Home</a>")

@app.get("/auth/logout")
def logout(request: Request):
    """Logout and clear session"""
    session_id = request.cookies.get("session_id")
    if session_id and session_id in token_store:
        del token_store[session_id]
    
    response = RedirectResponse(url="/", status_code=302)
    response.delete_cookie("session_id")
    return response


def require_auth(request: Request):
    """Check if user is authenticated, redirect to login if not"""
    session_id = request.cookies.get("session_id")
    user = token_store.get(session_id) if session_id else None
    
    if not user:
        login_url = get_login_url(request)
        raise HTTPException(
            status_code=307,
            headers={"Location": login_url}
        )
    return user

@app.get("/protected")
def protected_page(request: Request):
    """Protected page - redirects to login if not authenticated"""
    user = require_auth(request)
    return HTMLResponse(f"""
    <html>
    <body>
        <h1>Protected Page</h1>
        <p>Welcome, {user.get('email')}!</p>
        <p>User ID: {user.get('sub')}</p>
        <a href="/">Back to Home</a>
    </body>
    </html>
    """)

@app.get("/db-info")
def db_info(request: Request):
    """Protected endpoint that returns database connection info"""
    user = require_auth(request)
    host = os.getenv('DB_LOCATION')
    db_user = os.getenv('DB_USER')
    return {"host": host, "user": db_user, "logged_in_as": user.get('email')}

@app.get("/create")
def create_table(request: Request):
    """Protected endpoint to create a table in the database"""
    user = require_auth(request)
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS users (
                user_name VARCHAR(255) NOT NULL,
                created_by VARCHAR(255)
            );
        """)
        conn.commit()
        cursor.close()
        conn.close()
        return {"message": "Table 'users' created successfully", "created_by": user.get('email')}
    except Exception as e:
        return {"error": str(e)}

@app.get("/query")
def query_table(request: Request):
    """Protected endpoint to query the users table"""
    user = require_auth(request)
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users;")
        rows = cursor.fetchall()
        cursor.close()
        conn.close()
        return {"users": [row[0] for row in rows], "queried_by": user.get('email')}
    except Exception as e:
        return {"error": str(e)}

@app.get("/add-user/{username}")
def add_user(username: str, request: Request):
    """Protected endpoint to add a user to the database"""
    user = require_auth(request)
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO users (user_name, created_by) VALUES (%s, %s);",
            (username, user.get("email", "unknown"))
        )
        conn.commit()
        cursor.close()
        conn.close()
        return {"message": f"User '{username}' added successfully"}
    except Exception as e:
        return {"error": str(e)}

# API endpoints with Bearer token auth (for programmatic access)
@app.get("/api/auth-info")
def api_auth_info(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """API endpoint that requires Bearer token"""
    if not credentials:
        raise HTTPException(status_code=401, detail="Missing authorization header")
    
    user = cognito_auth.verify_token(credentials.credentials)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    return {"message": "Authenticated via API", "user": user}
