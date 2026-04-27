#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/voting-app-deploy.log) 2>&1

echo "=== Voting App Deployment Started $(date) ==="

# Wait for internet (NAT Gateway may take a moment)
MAX_WAIT=300
WAITED=0
until curl -s --max-time 5 https://aws.amazon.com > /dev/null 2>&1; do
  if [ $WAITED -ge $MAX_WAIT ]; then
    echo "ERROR: No internet after ${MAX_WAIT}s"
    exit 1
  fi
  echo "Waiting for internet... (${WAITED}s)"
  sleep 10
  WAITED=$((WAITED + 10))
done
echo "=== Internet OK (${WAITED}s) ==="

# Add 1GB swap (t2.micro has only 1GB RAM, need more for 5 containers)
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# Install Docker
yum update -y
amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Install Docker Compose v2
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Create voting app with Docker Hub images
# Images are built and pushed by GitHub Actions CI/CD pipeline
mkdir -p /opt/voting-app
cat > /opt/voting-app/docker-compose.yml << 'EOF'
services:
  vote:
    image: tranhaidang27/vote-app:latest
    ports:
      - "8080:80"
    depends_on:
      redis:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - front-tier
      - back-tier

  result:
    image: tranhaidang27/result-app:latest
    ports:
      - "8081:80"
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - front-tier
      - back-tier

  worker:
    image: tranhaidang27/worker-app:latest
    depends_on:
      redis:
        condition: service_healthy
      db:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - back-tier

  redis:
    image: redis:alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    restart: unless-stopped
    networks:
      - back-tier

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: "postgres"
      POSTGRES_PASSWORD: "postgres"
    volumes:
      - "db-data:/var/lib/postgresql/data"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 5
    restart: unless-stopped
    networks:
      - back-tier

volumes:
  db-data:

networks:
  front-tier:
  back-tier:
EOF

# Start voting app
cd /opt/voting-app
docker compose up -d

echo "=== Voting App Deployment Completed $(date) ==="
