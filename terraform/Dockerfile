FROM python:3.12-slim

RUN apt-get update && apt-get install -y curl unzip && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir boto3 azure-identity azure-mgmt-compute azure-mgmt-network azure-mgmt-resource

WORKDIR /app
EXPOSE 8000

CMD ["python3", "local_server.py"]
