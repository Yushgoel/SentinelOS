FROM ubuntu:22.04

# Install necessary packages
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    nano \
    curl \
    openssh-server \
    apache2 \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip3 install requests

# Set up SSH
RUN mkdir /var/run/sshd
RUN echo 'root:password' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Configure Apache to suppress the "server name" warning
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Create directories for our service
RUN mkdir -p /var/log/self-healing
WORKDIR /app

# Copy our healing daemon
COPY healing_daemon.py /app/
COPY self-healing.service /etc/systemd/system/
COPY startup.sh /app/
COPY test-break.sh /app/
COPY break-service.sh /app/

# Make scripts executable
RUN chmod +x /app/healing_daemon.py
RUN chmod +x /app/startup.sh
RUN chmod +x /app/test-break.sh
RUN chmod +x /app/break-service.sh

# Expose SSH port
EXPOSE 22
EXPOSE 80

# Set environment variable for the API key
ENV CLAUDE_API_KEY="your_api_key_here"

# Startup script 
CMD ["/app/startup.sh"]