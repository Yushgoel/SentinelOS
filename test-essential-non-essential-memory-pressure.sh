#!/bin/bash

# Function to create memory pressure with a non-essential process
create_memory_pressure() {
    local mem_size=$1
    # Use multiple workers and force memory allocation
    # stress-ng --vm 4 --vm-bytes "${mem_size}M" --vm-keep \
    #     --timeout 300s --aggressive --verify &
    
    # Also create a simple Python script that actually holds onto memory
    cat > memory_hog.py << 'EOF'
import time
import array
import sys

# Allocate memory in chunks to avoid sudden allocation
chunks = []
chunk_size = 200 * 1024 * 1024  # 200MB per chunk
num_chunks = 10  # Total 2GB

print("Starting memory allocation...")
for i in range(num_chunks):
    try:
        chunks.append(array.array('b', [1] * chunk_size))
        print(f"Allocated chunk {i+1}/{num_chunks}")
        sys.stdout.flush()
        time.sleep(1)
    except Exception as e:
        print(f"Failed to allocate chunk: {e}")
        break

print("Memory allocated, holding...")
while True:
    time.sleep(1)
EOF

    python3 memory_hog.py &
}

# Function to start nginx and create memory-intensive load
start_nginx_load() {
    # Install nginx, PHP and required extensions
    apt-get update && apt-get install -y nginx php-fpm php-gd apache2-utils

    # Create a PHP file that maintains high memory usage
    cat > /var/www/html/memory.php << 'EOF'
<?php
ini_set('memory_limit', '2048M');  // 2GB limit
session_start();

if (!isset($_SESSION['memory_blocks'])) {
    $_SESSION['memory_blocks'] = [];
}

// Function to get system memory info
function getSystemMemoryInfo() {
    $memInfo = file_get_contents('/proc/meminfo');
    preg_match('/MemTotal:\s+(\d+)/', $memInfo, $matches);
    $totalKB = isset($matches[1]) ? $matches[1] : 0;
    return $totalKB * 1024; // Convert to bytes
}

// Target using about 40% of system memory
$totalMemory = getSystemMemoryInfo();
$targetMemory = $totalMemory * 0.4;
$blockSize = 50 * 1024 * 1024; // 50MB blocks

// Create and store large arrays in session
while (memory_get_usage(true) < $targetMemory) {
    $block = str_repeat('x', $blockSize);
    $_SESSION['memory_blocks'][] = $block;
    echo "Current memory usage: " . round(memory_get_usage(true) / 1024 / 1024) . "MB\n";
    flush();
}

echo "Target memory usage achieved. Holding...\n";
sleep(1);
?>
EOF

    # Configure nginx with higher limits
    cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes 4;
worker_rlimit_nofile 100000;
pid /run/nginx.pid;

events {
    worker_connections 4096;
    multi_accept on;
}

http {
    include mime.types;
    default_type application/octet-stream;
    
    client_max_body_size 10M;
    client_body_timeout 300;
    keepalive_timeout 300;
    
    server {
        listen 80;
        root /var/www/html;
        index index.php index.html;
        
        location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/var/run/php/php-fpm.sock;
            fastcgi_read_timeout 300;
        }
    }
}
EOF

    # Configure PHP-FPM for higher memory limits and session handling
    cat > /etc/php/*/fpm/php.ini << 'EOF'
memory_limit = 2048M
max_execution_time = 300
session.save_handler = files
session.save_path = /var/lib/php/sessions
session.gc_maxlifetime = 3600
EOF

    # Restart services
    service php-fpm restart
    service nginx restart

    # Start multiple PHP-FPM workers to consume memory
    for i in {1..4}; do
        curl http://localhost/memory.php &
    done
}

echo "Starting memory pressure test with nginx+PHP server..."

# Install stress-ng if not present
if ! command -v stress-ng &> /dev/null; then
    echo "Installing stress-ng..."
    apt-get update && apt-get install -y stress-ng
fi

# First, start nginx with memory-intensive load
echo "Starting nginx+PHP server with memory-intensive load (essential service)..."
start_nginx_load

# Wait for nginx to start and build up memory usage
sleep 10

# Start the memory pressure process with more aggressive settings
echo "Starting non-essential memory-intensive processes consuming memory..."
create_memory_pressure 1024  # 2GB

echo "Both processes are now running:"
echo "- Nginx+PHP server (essential process that should be preserved)"
echo "- Non-essential memory pressure processes (can be killed)"
echo "The self-healing daemon should prioritize keeping the nginx process"
echo "Monitor with: docker exec self-healing-demo tail -f /var/log/self-healing/daemon.log"
echo "You can also monitor memory usage with: docker exec self-healing-demo top"

# Keep the script running
wait 