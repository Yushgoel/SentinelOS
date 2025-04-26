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
chunk_size = 100 * 1024 * 1024  # 100MB per chunk
num_chunks = 10  # Total 1GB

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

    # Create a PHP file that performs memory-intensive operations
    cat > /var/www/html/memory.php << 'EOF'
<?php
ini_set('memory_limit', '1024M');

// Create and manipulate large arrays
$data = [];
for ($i = 0; $i < 10; $i++) {
    $chunk = [];
    for ($j = 0; $j < 100000; $j++) {
        $chunk[] = str_repeat('x', 1024); // 1KB per element
    }
    $data[] = $chunk;
    echo "Allocated chunk " . ($i + 1) . "/10\n";
    flush();
}

// Generate and manipulate large images
for ($i = 0; $i < 3; $i++) {
    $width = 4096;
    $height = 4096;
    $image = imagecreatetruecolor($width, $height);
    
    // Fill with random pixels
    for ($x = 0; $x < $width; $x += 2) {
        for ($y = 0; $y < $height; $y += 2) {
            $color = imagecolorallocate($image, rand(0, 255), rand(0, 255), rand(0, 255));
            imagesetpixel($image, $x, $y, $color);
        }
    }
    
    // Apply filters
    imagefilter($image, IMG_FILTER_GAUSSIAN_BLUR);
    imagefilter($image, IMG_FILTER_SMOOTH, 5);
    
    $data[] = $image;
    echo "Processed image " . ($i + 1) . "/3\n";
    flush();
}

sleep(2);
echo "Memory intensive operations completed\n";
?>
EOF

    # Configure nginx
    cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
worker_rlimit_nofile 100000;
events {
    worker_connections 4096;
}
http {
    include mime.types;
    default_type application/octet-stream;
    
    client_body_buffer_size 10M;
    client_max_body_size 10M;
    client_body_timeout 300;
    client_header_timeout 300;
    keepalive_timeout 300;
    fastcgi_read_timeout 300;
    
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

    # Configure PHP-FPM
    cat > /etc/php/*/fpm/php.ini << 'EOF'
memory_limit = 1024M
max_execution_time = 300
EOF

    # Restart services
    service php-fpm restart
    service nginx restart

    # Start requests
    for i in {1..3}; do
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