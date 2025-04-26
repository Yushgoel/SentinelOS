#!/bin/bash

# Log file
LOG_FILE="/var/log/self-healing/vpn_events.log"

# Create log directory if it doesn't exist
mkdir -p /var/log/self-healing

# Function to log messages
log_message() {
    echo "$(date): $1" | tee -a $LOG_FILE
}

# Check if VPN interface exists, create it if it doesn't
if ! ip link show vpn0 &>/dev/null; then
    log_message "VPN interface 'vpn0' does not exist. Creating it first..."
    /app/simulate-vpn.sh create
    sleep 2
fi

# Break the VPN connection with a firewall kill-switch
log_message "VPN connection down"

# First, take down the VPN interface
ip link set vpn0 down
echo "0" > /var/run/vpn_status

# Add firewall rules to block all traffic on the VPN interface - add explicit logging
log_message "Adding firewall rules to block VPN traffic"
iptables -F
iptables -A INPUT -i vpn0 -j DROP
iptables -A OUTPUT -o vpn0 -j DROP

# To make things more difficult, make the interface unmanageable - add explicit logging
log_message "Adding network rules to restrict VPN management"
iptables -A INPUT -p all -m string --string "vpn0" --algo bm -j DROP
iptables -A OUTPUT -p all -m string --string "vpn0" --algo bm -j DROP

# Verify the VPN is broken
if ! ip link show vpn0 | grep -q "UP"; then
    log_message "VPN interface 'vpn0' is now DOWN"
    echo "VPN connection is down. The self-healing daemon will try to fix it."
else
    log_message "Failed to break VPN interface"
    echo "Failed to break VPN connection."
fi

# Start monitoring the healing process
echo "Monitoring healing attempts..."

# Function to extract command from logs
get_last_command() {
    grep "Attempting to fix vpn with command:" /var/log/self-healing/daemon.log | tail -1 | awk -F': ' '{print $2}'
}

# Watch for self-healing attempts
attempt_count=0
max_attempts=5
last_command=""

while [ $attempt_count -lt $max_attempts ]; do
    # Sleep to give the daemon time to detect and attempt a fix
    sleep 10
    
    # Check if the daemon tried to fix the VPN
    current_command=$(get_last_command)
    
    if [ "$current_command" != "$last_command" ]; then
        # New attempt detected
        attempt_count=$((attempt_count + 1))
        last_command=$current_command
        
        echo "Healing attempt #$attempt_count detected: $current_command"
        
        # If the daemon used the "create" command and it failed, add subtle clues to logs
        if [[ "$current_command" == *"create"* ]]; then
            log_message "VPN still not connecting after attempt to create"
            log_message "Connection attempt failed"
            
            # After standard method fails, add very minimal hints without revealing solution
            if [ $attempt_count -ge 2 ]; then
                # Add minimal logs indicating connection failures but no direct mention of firewalls
                log_message "Error: Network connection blocked"
                log_message "Network rules preventing connection"
            fi
            
            # Break the loop to give Claude another chance
            break
        fi
        
        # If we detect a firewall flush attempt, note that the daemon found the solution
        if grep -q "flush firewall rules" /var/log/self-healing/daemon.log; then
            echo "Alternative solution found!"
            break
        fi
    fi
    
    # Check if the VPN has been restored
    if ip link show vpn0 &>/dev/null && ip link show vpn0 | grep -q "UP"; then
        if [ "$(cat /var/run/vpn_status 2>/dev/null)" == "1" ]; then
            echo "VPN has been restored successfully."
            break
        fi
    fi
done

# If we reached max attempts without success, just say it's still not working
if [ $attempt_count -ge $max_attempts ]; then
    echo "Multiple healing attempts made but VPN is still not working."
fi

echo "Test completed. Check logs for details."
exit 0 