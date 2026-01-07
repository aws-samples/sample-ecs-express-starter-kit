FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY hello-world.py .

EXPOSE 8000

CMD ["uvicorn", "hello-world:app", "--host", "0.0.0.0", "--port", "8000"]


# docker build --platform linux/amd64 -t public.ecr.aws/p7b6k2h9/mod-app:0.0.9 .