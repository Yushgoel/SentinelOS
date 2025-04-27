#!/bin/bash

# Build the Docker image
echo "Building Docker image..."
docker build -t self-healing-linux .

# Stop and remove existing container if it exists
if [ "$(docker ps -a -q -f name=self-healing-demo)" ]; then
  echo "Stopping and removing existing container..."
  docker stop self-healing-demo
  docker rm self-healing-demo
fi

# Run the container with env file
echo "Starting self-healing demo container..."
docker run -d --name self-healing-demo \
  -p 2222:22 \
  -p 8080:80 \
  -p 8501:8501 \
  --env-file .env \
  self-healing-linux

echo "Waiting for container to initialize..."
sleep 3

echo "Container started! You can view logs with:"
echo "docker logs self-healing-demo"
echo ""
echo "Test service failure with:"
echo "docker exec -it self-healing-demo /app/test-break.sh"
echo ""
echo "To see continuous logs:"
echo "docker logs -f self-healing-demo"