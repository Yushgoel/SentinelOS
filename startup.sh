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
daemon_pid=$!
echo "Self-healing daemon started with PID: $daemon_pid"

# Start the streamlit dashboard in the background
echo "Starting Streamlit dashboard..."
nohup streamlit run /app/dashboard.py --server.port 8501 --server.address 0.0.0.0 > /var/log/self-healing/dashboard.log 2>&1 &
dashboard_pid=$!
echo "Streamlit dashboard started with PID: $dashboard_pid"

# Give services a moment to start
sleep 2

# Check if processes are running
if ps -p $daemon_pid > /dev/null; then
    echo "Daemon is running"
else
    echo "Warning: Daemon failed to start"
fi

if ps -p $dashboard_pid > /dev/null; then
    echo "Dashboard is running"
else
    echo "Warning: Dashboard failed to start"
fi

# Keep container running and show logs
echo "Demo environment running. Use another terminal to interact with it."
echo "View daemon logs with: docker exec self-healing-demo tail -f /var/log/self-healing/daemon.log"
echo "View dashboard logs with: docker exec self-healing-demo tail -f /var/log/self-healing/dashboard.log"
echo "Break a service with: docker exec self-healing-demo /app/test-break.sh"

# Watch the daemon log file
echo "Showing daemon log output:"
tail -f /var/log/self-healing/daemon.log