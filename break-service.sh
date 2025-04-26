#!/bin/bash

# Create log directory if it doesn't exist
mkdir -p /var/log/self-healing

# Log file
LOG_FILE="/var/log/self-healing/break_service.log"

# Log the date and time
echo "$(date): Running break-service.sh" >> $LOG_FILE

# Randomly select a service to break
services=("apache2" "ssh" "vpn")

# Show array size for debugging
echo "$(date): Service array size: ${#services[@]}" >> $LOG_FILE

RAND_NUM=$RANDOM
MOD_RESULT=$(($RAND_NUM % ${#services[@]}))
selected_service=${services[$MOD_RESULT]}

# Log the random selection process
echo "$(date): RANDOM value: $RAND_NUM" >> $LOG_FILE
echo "$(date): Modulo result (index): $MOD_RESULT" >> $LOG_FILE
echo "$(date): Selected service: $selected_service" >> $LOG_FILE

echo "Breaking $selected_service service..."

# Stop the selected service
if [ "$selected_service" = "vpn" ]; then
    # Use VPN-specific break script for VPN
    echo "$(date): Using break-vpn.sh to break VPN" >> $LOG_FILE
    /app/break-vpn.sh
else
    # Use standard service stop for other services
    echo "$(date): Using 'service stop' to break $selected_service" >> $LOG_FILE
    service $selected_service stop
    echo "Service $selected_service has been stopped. The self-healing daemon should detect and fix this shortly."
fi 