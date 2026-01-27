FROM amazonlinux:2023

WORKDIR /app

# Install Python 3.12, pip and user tools
RUN dnf install -y python3.12 python3.12-pip shadow-utils && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Create non-root user for security
RUN useradd -r -s /bin/false appuser

COPY requirements.txt .
RUN python3.12 -m pip install --no-cache-dir -r requirements.txt

COPY hello-world.py .

# Switch to non-root user
USER appuser

EXPOSE 8000

# CMD ["python3.12", "-m", "uvicorn", "hello-world:app", "--host", "0.0.0.0", "--port", "8000"]


CMD ["uvicorn", "hello-world:app", "--host", "0.0.0.0", "--port", "8000"]


# docker build --platform linux/amd64 -t public.ecr.aws/p7b6k2h9/mod-app:0.0.9 .