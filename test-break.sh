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

# Update service file with actual API key
sed -i "s|%CLAUDE_API_KEY%|$CLAUDE_API_KEY|g" /etc/systemd/system/self-healing.service

# Start the healing daemon in the background
echo "Starting self-healing daemon..."
python3 /app/healing_daemon.py > /var/log/self-healing/daemon.log 2>&1 &
daemon_pid=$!

# Start the streamlit dashboard in the background
echo "Starting Streamlit dashboard..."
nohup streamlit run /app/dashboard.py --server.port 8501 --server.address 0.0.0.0 > /var/log/self-healing/dashboard.log 2>&1 &
dashboard_pid=$!


# Keep container running
echo "Demo environment running. Use another terminal to interact with it."
echo "View logs with: docker exec self-healing-demo tail -f /var/log/self-healing/daemon.log"
echo "Break a service with: docker exec self-healing-demo /app/break-service.sh"

# Keep container running
tail -f /var/log/self-healing/daemon.log