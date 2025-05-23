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

# Start the self-healing daemon in the background
echo "Starting self-healing daemon..."
python3 /app/healing_daemon.py &

# Start the Streamlit dashboard
echo "Starting dashboard..."
streamlit run /app/dashboard.py --server.port 8501 --server.address 0.0.0.0 &

# Keep container running
echo "Demo environment running. Use another terminal to interact with it."
echo "View logs with: docker exec self-healing-demo tail -f /var/log/self-healing/daemon.log"
echo "View dashboard at: http://localhost:8501"
echo "Break a service with: docker exec self-healing-demo /app/break-service.sh"

# Keep container running
tail -f /var/log/self-healing/daemon.log