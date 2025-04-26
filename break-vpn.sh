#!/bin/bash

# Log file
LOG_FILE="/var/log/self-healing/vpn_events.log"

# Check if VPN interface exists
if ! ip link show vpn0 &>/dev/null; then
    echo "VPN interface 'vpn0' does not exist. Creating it first..." | tee -a $LOG_FILE
    /app/simulate-vpn.sh create
    sleep 2
fi

# Break the VPN connection
echo "$(date): Breaking VPN connection..." | tee -a $LOG_FILE
ip link set vpn0 down

# Verify it's broken
if ! ip link show vpn0 | grep -q "UP"; then
    echo "$(date): VPN interface 'vpn0' is now DOWN (disconnected)" | tee -a $LOG_FILE
    echo "0" > /var/run/vpn_status
    echo "VPN successfully broken. The self-healing daemon should detect and fix this shortly."
else
    echo "$(date): Failed to break VPN interface" | tee -a $LOG_FILE
    echo "Failed to break VPN connection."
fi 