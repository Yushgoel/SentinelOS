#!/bin/bash

# Start the SSH service
service ssh start
echo "SSH service started"

# Start Apache
service apache2 start
echo "Apache service started"

# Enable logging
service rsyslog start
echo "Logging service started"

# Setup VPN interface
echo "Setting up VPN interface..."
chmod +x /app/simulate-vpn.sh
chmod +x /app/break-vpn.sh
/app/simulate-vpn.sh create
echo "VPN interface created"

# Update service file with actual API key
sed -i "s|%CLAUDE_API_KEY%|$CLAUDE_API_KEY|g" /etc/systemd/system/self-healing.service

# Start the self-healing daemon in the background
echo "Starting self-healing daemon..."
python3 /app/healing_daemon.py &

# Keep container running
echo "Demo environment running. Use another terminal to interact with it."
echo "View logs with: docker exec self-healing-demo tail -f /var/log/self-healing/daemon.log"
echo "Break a service with: docker exec self-healing-demo /app/break-service.sh"
echo "Break VPN with: docker exec self-healing-demo /app/break-vpn.sh"

# Keep container running
tail -f /var/log/self-healing/daemon.log