#!/bin/bash

# Note about VPN simulation
echo "VPN simulation will be handled inside the container on Ubuntu..."
# The modprobe dummy command is not needed on macOS and will be handled inside the container

# Build the Docker image
echo "Building Docker image..."
docker build -t self-healing-linux .

# Stop and remove existing container if it exists
if [ "$(docker ps -a -q -f name=self-healing-demo)" ]; then
  echo "Stopping and removing existing container..."
  docker stop self-healing-demo
  docker rm self-healing-demo
fi

# Run the container with env file and necessary privileges
echo "Starting self-healing demo container with network privileges..."
docker run -d --name self-healing-demo \
  --privileged \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  -p 2222:22 \
  -p 8080:80 \
  --env-file .env \
  self-healing-linux

echo "Waiting for container to initialize..."
sleep 3

echo "Container started! You can view logs with:"
echo "docker logs self-healing-demo"
echo ""
echo "Test service failure with:"
echo "docker exec -it self-healing-demo /app/break-service.sh"
echo ""
echo "Break the VPN with:"
echo "docker exec -it self-healing-demo /app/break-vpn.sh"
echo ""
echo "Break VPN with firewall kill-switch (advanced):"
echo "docker exec -it self-healing-demo /app/break-vpn-firewall.sh"
echo ""
echo "Test VPN firewall kill-switch fix:"
echo "docker exec -it self-healing-demo /app/test-vpn-firewall-fix.sh"
echo ""
echo "Debug random service selection:"
echo "docker exec -it self-healing-demo /app/check-random.sh"
echo ""
echo "To see continuous logs:"
echo "docker logs -f self-healing-demo"