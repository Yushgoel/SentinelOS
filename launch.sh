#!/bin/bash

# Build the Docker image
echo "Building Docker image..."
docker build -t self-healing-linux .

# Check if CLAUDE_API_KEY is set
if [ -z "$CLAUDE_API_KEY" ]; then
    echo "Warning: CLAUDE_API_KEY environment variable not set. AI diagnosis will use fallback mode."
fi

# Remove existing container if it exists
if docker ps -a | grep -q "self-healing-demo"; then
    echo "Found existing container, removing it..."
    docker rm -f self-healing-demo
fi

# Run the container
echo "Starting container..."
docker run -d \
    --name self-healing-demo \
    -p 2222:22 \
    -p 8080:80 \
    -p 8501:8501 \
    -e CLAUDE_API_KEY="$CLAUDE_API_KEY" \
    self-healing-linux

echo "Container started!"
echo
echo "Access points:"
echo "- SSH: ssh root@localhost -p 2222 (password: password)"
echo "- Web server: http://localhost:8080"
echo "- Dashboard: http://localhost:8501"
echo
echo "Useful commands:"
echo "- View logs: docker exec self-healing-demo tail -f /var/log/self-healing/daemon.log"
echo "- Break a service: docker exec self-healing-demo /app/test-break.sh"
echo "- Test memory pressure: docker exec self-healing-demo /app/test-essential-non-essential-memory-pressure.sh"
echo "- Stop container: docker stop self-healing-demo"
echo "- Remove container: docker rm self-healing-demo"