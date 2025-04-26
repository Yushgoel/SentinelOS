#!/bin/bash

# Log file
LOG_FILE="/var/log/self-healing/vpn_events.log"

# Create log directory if it doesn't exist
mkdir -p /var/log/self-healing

# Function to log messages
log_message() {
    echo "$(date): $1" | tee -a $LOG_FILE
}

# Create a dummy network interface to simulate VPN
create_vpn() {
    log_message "Creating dummy VPN interface 'vpn0'..."
    
    # Check for existing vpn0 interface and remove if it exists
    if ip link show vpn0 &>/dev/null; then
        log_message "VPN interface already exists, removing first..."
        ip link delete vpn0 2>/dev/null
    fi
    
    # Try different methods to load the dummy module
    modprobe dummy 2>/dev/null || log_message "Warning: modprobe dummy failed, but continuing..."
    
    # If modprobe fails, we can still try to create the interface
    log_message "Attempting to create dummy interface..."
    
    # Method 1: Try standard dummy creation
    ip link add vpn0 type dummy 2>/dev/null
    
    # Method 2: If that fails, try using tuntap
    if ! ip link show vpn0 &>/dev/null; then
        log_message "Standard dummy creation failed, trying alternative method..."
        ip tuntap add dev vpn0 mode tap 2>/dev/null
    fi
    
    # Wait a moment for interface to be fully created
    sleep 1
    
    # Check if interface was created
    if ip link show vpn0 &>/dev/null; then
        log_message "Successfully created VPN interface, configuring IP..."
        ip addr add 10.8.0.1/24 dev vpn0
        ip link set vpn0 up
        
        # Verify interface is up
        if ip link show vpn0 | grep -q "UP"; then
            log_message "VPN interface 'vpn0' is now UP and RUNNING"
            echo "1" > /var/run/vpn_status
            return 0
        else
            log_message "Interface created but couldn't be brought UP"
            echo "0" > /var/run/vpn_status
            return 1
        fi
    else
        log_message "Failed to create VPN interface. Using simulated VPN status file instead."
        # If we can't create a real interface, just simulate it with a status file
        echo "1" > /var/run/vpn_status
        log_message "Created simulated VPN status (active)"
        return 0
    fi
}

# Simulate a VPN disconnection
disconnect_vpn() {
    log_message "Simulating VPN disconnection..."
    
    # First check if we're using a real interface or just simulating
    if ip link show vpn0 &>/dev/null; then
        # We have a real interface, take it down
        ip link set vpn0 down
        
        # Verify status
        if ! ip link show vpn0 | grep -q "UP"; then
            log_message "VPN interface 'vpn0' is now DOWN (disconnected)"
            echo "0" > /var/run/vpn_status
        else
            log_message "Failed to disconnect real VPN interface, using status file instead"
            echo "0" > /var/run/vpn_status
        fi
    else
        # Just using the status file
        log_message "Using simulated VPN disconnection (no real interface)"
        echo "0" > /var/run/vpn_status
    fi
}

# Check VPN status
check_vpn() {
    # First check if we're using a real interface
    if ip link show vpn0 &>/dev/null; then
        if ip link show vpn0 | grep -q "UP"; then
            log_message "VPN status: CONNECTED (UP) - Real interface"
            echo "1" > /var/run/vpn_status
        else
            log_message "VPN status: DISCONNECTED (DOWN) - Real interface"
            echo "0" > /var/run/vpn_status
        fi
    else
        # Just check the status file
        if [ -f /var/run/vpn_status ] && [ "$(cat /var/run/vpn_status)" == "1" ]; then
            log_message "VPN status: CONNECTED (Simulated)"
        else
            log_message "VPN status: DISCONNECTED (Simulated)"
        fi
    fi
}

# Reconnect the VPN
reconnect_vpn() {
    log_message "Reconnecting VPN..."
    
    # Check if we're using a real interface
    if ip link show vpn0 &>/dev/null; then
        # Bring the interface back up
        ip link set vpn0 up
        
        # Verify status
        if ip link show vpn0 | grep -q "UP"; then
            log_message "VPN interface 'vpn0' is now UP (reconnected)"
            echo "1" > /var/run/vpn_status
        else
            log_message "Failed to reconnect real VPN interface, using status file instead"
            echo "1" > /var/run/vpn_status
        fi
    else
        # Just using the status file or try to create the interface
        log_message "No real interface found, attempting to create one..."
        create_vpn || {
            log_message "Could not create real interface, using simulated reconnection"
            echo "1" > /var/run/vpn_status
        }
    fi
}

# Show command help
show_help() {
    echo "Usage: $0 [create|disconnect|check|reconnect]"
    echo "  create      - Create and start the dummy VPN interface"
    echo "  disconnect  - Simulate VPN disconnection"
    echo "  check       - Check current VPN status"
    echo "  reconnect   - Reconnect the VPN interface"
}

# Main logic based on command line argument
case "$1" in
    # create)
    #     create_vpn
    #     ;;
    disconnect)
        disconnect_vpn
        ;;
    check)
        check_vpn
        ;;
    reconnect)
        reconnect_vpn
        ;;
    *)
        show_help
        exit 1
        ;;
esac

exit 0 