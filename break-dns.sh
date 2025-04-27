#!/bin/bash

echo "Breaking DNS resolution by modifying resolv.conf..."

# Backup the current resolv.conf if backup doesn't exist
if [ ! -f /etc/resolv.conf.bak ]; then
    cp /etc/resolv.conf /etc/resolv.conf.bak
    echo "Created backup of current resolv.conf at /etc/resolv.conf.bak"
fi

# Choose a random method to mess up resolv.conf
methods=("invalid_nameservers" "empty_file" "invalid_format" "unreachable_nameservers")
selected_method=${methods[$RANDOM % ${#methods[@]}]}

case $selected_method in
    "invalid_nameservers")
        echo "Method: Setting invalid nameservers"
        echo "nameserver 1.1.1.123" > /etc/resolv.conf
        echo "nameserver 8.8.8.123" >> /etc/resolv.conf
        ;;
    "empty_file")
        echo "Method: Emptying resolv.conf file"
        echo "" > /etc/resolv.conf
        ;;
    "invalid_format")
        echo "Method: Creating invalid resolv.conf format"
        echo "This is not a valid resolv.conf file" > /etc/resolv.conf
        echo "nameservers 8.8.8.8" >> /etc/resolv.conf  # Incorrect keyword
        ;;
    "unreachable_nameservers")
        echo "Method: Setting unreachable nameservers"
        echo "nameserver 192.168.255.254" > /etc/resolv.conf
        echo "nameserver 10.255.255.254" >> /etc/resolv.conf
        ;;
esac

echo "DNS resolution has been broken. The self-healing daemon should detect and fix this shortly."

# Test the breakage
echo "Testing DNS resolution..."
if ping -c 1 -W 2 google.com &>/dev/null; then
    echo "WARNING: DNS resolution still works, breakage may not have been successful."
else
    echo "Confirmed: DNS resolution is broken."
fi 