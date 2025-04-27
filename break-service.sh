#!/bin/bash

# Randomly select a service or DNS to break
services=("apache2" "ssh" "dns")
selected_service=${services[$RANDOM % ${#services[@]}]}

echo "Breaking $selected_service service..."

if [ "$selected_service" == "dns" ]; then
    # Backup the current resolv.conf
    cp /etc/resolv.conf /etc/resolv.conf.bak
    
    # Replace with invalid nameservers
    echo "nameserver 1.1.1.123" > /etc/resolv.conf
    echo "nameserver 8.8.8.123" >> /etc/resolv.conf
    
    echo "DNS resolution has been broken. The self-healing daemon should detect and fix this shortly."
else
    # Stop the selected service
    service $selected_service stop
    
    echo "Service $selected_service has been stopped. The self-healing daemon should detect and fix this shortly."
fi 