import os
import psycopg2
from fastapi import FastAPI, Depends
from starlette.middleware.sessions import SessionMiddleware


# Import our new separate auth module
from auth import router as auth_router, get_current_user, register_auth_exception_handler


app = FastAPI()

# Session middleware configuration
app.add_middleware(
    SessionMiddleware, 
    secret_key=os.getenv("APP_SECRET_KEY"),
    https_only=os.getenv("ENV") == "production",
    same_site="lax"    
)

# Register Auth0 routes and exception handlers
app.include_router(auth_router)
register_auth_exception_handler(app)

# --- App Functions ---

@app.get("/")
def hello_world(user: dict = Depends(get_current_user)):
    host = os.getenv('DB_LOCATION')
    user = os.getenv('DB_USER')
    password = os.getenv('DB_PASSWORD')
        
    return {"host": host, "user": user, "password": password, "auth_user": user.get("email")}

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