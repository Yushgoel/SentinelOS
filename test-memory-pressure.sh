#!/bin/bash

# Function to consume memory
consume_memory() {
    # Use stress-ng to actually consume memory
    stress-ng --vm 1 --vm-bytes "${1}M" --timeout 60s &
}

echo "Starting memory pressure test..."
echo "This will create several memory-intensive processes"

# Install stress-ng if not present
if ! command -v stress-ng &> /dev/null; then
    echo "Installing stress-ng..."
    apt-get update && apt-get install -y stress-ng
fi

# Start with smaller chunks and gradually increase
for i in 256 512 1024 2048; do
    echo "Allocating ${i}MB of memory..."
    consume_memory $i
    sleep 2
done

echo "Memory pressure processes started"
echo "The self-healing daemon should detect and handle the memory issue"
echo "Monitor with: docker exec self-healing-demo tail -f /var/log/self-healing/daemon.log"

# Keep the script running to maintain pressure
wait 