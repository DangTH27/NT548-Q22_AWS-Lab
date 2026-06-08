#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/voting-app-deploy.log) 2>&1

echo "=== Voting App Swarm Node Deployment Started $(date) ==="

# Wait for internet
MAX_WAIT=300
WAITED=0
until curl -s --max-time 5 https://aws.amazon.com > /dev/null 2>&1; do
  if [ $WAITED -ge $MAX_WAIT ]; then
    echo "ERROR: No internet after $${MAX_WAIT}s"
    exit 1
  fi
  sleep 10
  WAITED=$((WAITED + 10))
done

# Add Swap (t2.micro needs more memory for Swarm)
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

NODE_INDEX=${node_index}

if [ "$NODE_INDEX" -eq 0 ]; then
  echo "=== I am the Swarm MANAGER ==="
  
  # Get private IP
  PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
  
  # Initialize Swarm
  docker swarm init --advertise-addr $PRIVATE_IP
  
  # Extract worker token
  WORKER_TOKEN=$(docker swarm join-token -q worker)
  
  # Store token and IP in AWS SSM Parameter Store
  aws ssm put-parameter --name "/voting-app/swarm-token" --value "$WORKER_TOKEN" --type "SecureString" --overwrite --region ap-southeast-1
  aws ssm put-parameter --name "/voting-app/manager-ip" --value "$PRIVATE_IP" --type "String" --overwrite --region ap-southeast-1
  
  # Create docker-compose.yml for stack deploy
  mkdir -p /opt/voting-app
  cat > /opt/voting-app/docker-compose.yml << 'EOF'
version: '3.8'
services:
  vote:
    image: tranhaidang27/vote-app:latest
    ports:
      - "8080:80"
    networks:
      - front-tier
      - back-tier
    deploy:
      replicas: 2

  result:
    image: tranhaidang27/result-app:latest
    ports:
      - "8081:80"
    networks:
      - front-tier
      - back-tier
    deploy:
      replicas: 2

  worker:
    image: tranhaidang27/worker-app:latest
    networks:
      - back-tier
    deploy:
      replicas: 1

  redis:
    image: redis:alpine
    networks:
      - back-tier
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: "postgres"
      POSTGRES_PASSWORD: "postgres"
    volumes:
      - "db-data:/var/lib/postgresql/data"
    networks:
      - back-tier
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager

volumes:
  db-data:

networks:
  front-tier:
  back-tier:
EOF

  cd /opt/voting-app
  docker stack deploy -c docker-compose.yml voting-app
  
else
  echo "=== I am a Swarm WORKER ==="
  
  # Wait for token and manager IP to be available in SSM
  echo "Waiting for Swarm manager token..."
  until aws ssm get-parameter --name "/voting-app/swarm-token" --region ap-southeast-1 > /dev/null 2>&1; do
    sleep 10
  done
  
  WORKER_TOKEN=$(aws ssm get-parameter --name "/voting-app/swarm-token" --with-decryption --query "Parameter.Value" --output text --region ap-southeast-1)
  MANAGER_IP=$(aws ssm get-parameter --name "/voting-app/manager-ip" --query "Parameter.Value" --output text --region ap-southeast-1)
  
  echo "Joining swarm cluster at $MANAGER_IP..."
  docker swarm join --token "$WORKER_TOKEN" "$MANAGER_IP:2377"
fi

echo "=== Voting App Swarm Node Deployment Completed $(date) ==="
