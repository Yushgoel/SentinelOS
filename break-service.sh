#!/bin/bash

# Randomly select a service to break
services=("apache2" "ssh")
selected_service=${services[$RANDOM % ${#services[@]}]}

echo "Breaking $selected_service service..."

# Stop the selected service
service $selected_service stop

echo "Service $selected_service has been stopped. The self-healing daemon should detect and fix this shortly." 