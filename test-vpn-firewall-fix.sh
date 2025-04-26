#!/bin/bash

# Log file
LOG_FILE="/var/log/self-healing/vpn_firewall_test.log"

# Create log directory if it doesn't exist
mkdir -p /var/log/self-healing

# Function to log messages
log_message() {
    echo "$(date): $1" | tee -a $LOG_FILE
}

# First make sure the VPN is working
log_message "Ensuring VPN is working initially..."
/app/simulate-vpn.sh create
sleep 2

# Verify VPN status
if ip link show vpn0 | grep -q "UP"; then
    log_message "VPN interface is UP and running. Proceeding with test."
else
    log_message "VPN interface is not running. Initial setup failed."
    echo "VPN setup failed. Aborting test."
    exit 1
fi

# Break the VPN using the firewall kill-switch
log_message "Breaking VPN with firewall kill-switch..."
./break-vpn-firewall.sh &
BREAK_PID=$!
log_message "Firewall kill-switch script started with PID: $BREAK_PID"

# Wait for the script to run
log_message "Waiting for VPN to be broken and healing attempts to complete..."
wait $BREAK_PID

log_message "Test completed. Check the daemon logs to see the full healing process."
echo "Test completed. The logs should show if the daemon successfully detected and fixed the VPN issue."

exit 0 