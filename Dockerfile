FROM ubuntu:22.04

# Install necessary packages
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    nano \
    systemd \
    curl \
    openssh-server \
    apache2 \
    rsyslog \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip3 install requests

# Set up SSH
RUN mkdir /var/run/sshd
RUN echo 'root:password' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Create directories for our service
RUN mkdir -p /var/log/self-healing
WORKDIR /app

# Copy our healing daemon
COPY healing_daemon.py /app/
COPY self-healing.service /etc/systemd/system/
COPY startup.sh /app/
COPY test-break.sh /app/

# Make scripts executable
RUN chmod +x /app/healing_daemon.py
RUN chmod +x /app/startup.sh
RUN chmod +x /app/test-break.sh

# Expose SSH port
EXPOSE 22
EXPOSE 80

# Set environment variable for the API key
ENV CLAUDE_API_KEY="your_api_key_here"

# Startup script 
CMD ["/app/startup.sh"]