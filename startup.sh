#!/bin/bash

# Create log directory explicitly
mkdir -p /var/log/self-healing
touch /var/log/self-healing/daemon.log

# Start the SSH service
service ssh start
echo "SSH service started"

# Start Apache
service apache2 start
echo "Apache service started"

# Update service file with actual API key
sed -i "s|%CLAUDE_API_KEY%|$CLAUDE_API_KEY|g" /etc/systemd/system/self-healing.service

# Start the self-healing daemon in the background
echo "Starting self-healing daemon..."
python3 /app/healing_daemon.py > /var/log/self-healing/daemon.log 2>&1 &
pid=$!
echo "Self-healing daemon started with PID: $pid"

# Keep container running
echo "Demo environment running. Use another terminal to interact with it."
echo "View logs with: docker exec self-healing-demo tail -f /var/log/self-healing/daemon.log"
echo "Break a service with: docker exec self-healing-demo /app/test-break.sh"

# Watch the log file instead of trying to tail a non-existent file
echo "Showing log output:"
tail -f /var/log/self-healing/daemon.log