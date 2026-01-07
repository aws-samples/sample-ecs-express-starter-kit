from fastapi import FastAPI
import os
import psycopg2
from psycopg2 import sql

app = FastAPI()


@app.get("/")
def hello_world():
    # return {"message": "Hello, World!"}
    host = os.getenv('DB_LOCATION')
    user = os.getenv('DB_USER')
    password = os.getenv('DB_PASSWORD')
        
    return {"host": host, "user": user, "password": password}

@app.get("/create")
def create_table():
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
def query_table():
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
