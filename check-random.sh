#!/bin/bash

# Create log file if it doesn't exist
touch /var/log/self-healing/break_service.log

# Run the break-service.sh script
/app/break-service.sh

# Wait a moment for logs to be written
sleep 1

# Display the random selection logs
echo "========== Random Selection Logs =========="
cat /var/log/self-healing/break_service.log
echo "=========================================="

echo ""
echo "To check which service was actually broken, run:"
echo "docker exec self-healing-demo tail -f /var/log/self-healing/daemon.log" 