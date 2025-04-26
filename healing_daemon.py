#!/usr/bin/env python3

import subprocess
import time
import json
import logging
import os
import sys
import requests
from datetime import datetime

# Ensure log directory exists
os.makedirs("/var/log/self-healing", exist_ok=True)

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("/var/log/self-healing/daemon.log"),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("self-healing")

class SelfHealingDaemon:
    def __init__(self, api_key=None, auto_fix=True):
        self.api_key = api_key
        self.auto_fix = auto_fix
        self.monitored_services = ["ssh", "apache2"]
        self.service_status = {}
        self.api_url = "https://api.anthropic.com/v1/messages"
        self.memory_threshold = 90  # Memory usage threshold percentage
        
        logger.info("Self-Healing Daemon initialized")
        if not api_key:
            logger.warning("No API key provided - will use fallback diagnosis")
        
    def monitor_services(self):
        """Check the status of all monitored services"""
        for service in self.monitored_services:
            try:
                # Simplified service check for Docker demo
                if service == "ssh":
                    result = subprocess.run(
                        ["pgrep", "sshd"],
                        capture_output=True, text=True, check=False
                    )
                    status = "active" if result.returncode == 0 else "inactive"
                elif service == "apache2":
                    result = subprocess.run(
                        ["pgrep", "apache2"],
                        capture_output=True, text=True, check=False
                    )
                    status = "active" if result.returncode == 0 else "inactive"
                else:
                    status = "unknown"
                
                # If status changed, log it
                if service in self.service_status and self.service_status[service] != status:
                    logger.info(f"Service {service} changed from {self.service_status[service]} to {status}")
                
                self.service_status[service] = status
                logger.info(f"Service {service} status: {status}")
            except Exception as e:
                logger.error(f"Error checking service {service}: {str(e)}")
                self.service_status[service] = "unknown"
    
    def get_service_logs(self, service, lines=20):
        """Get logs for a service (simplified for demo)"""
        try:
            if service == "ssh":
                # Create log file if it doesn't exist
                if not os.path.exists("/var/log/auth.log"):
                    with open("/var/log/auth.log", "w") as f:
                        f.write("SSH log file created for demo\n")
                
                result = subprocess.run(
                    ["cat", "/var/log/auth.log"],
                    capture_output=True, text=True, check=False
                )
                return result.stdout or "No SSH logs found"
            elif service == "apache2":
                # Create log file if it doesn't exist
                os.makedirs("/var/log/apache2", exist_ok=True)
                if not os.path.exists("/var/log/apache2/error.log"):
                    with open("/var/log/apache2/error.log", "w") as f:
                        f.write("Apache error log file created for demo\n")
                
                result = subprocess.run(
                    ["cat", "/var/log/apache2/error.log"],
                    capture_output=True, text=True, check=False
                )
                return result.stdout or "No Apache logs found"
            return "No logs available for this service"
        except Exception as e:
            logger.error(f"Error getting logs for {service}: {str(e)}")
            return f"Error getting logs: {str(e)}"
    
    def diagnose_issue(self, service, logs):
        """Use Claude to diagnose the issue"""
        if not self.api_key:
            logger.warning("No API key provided - using fallback diagnosis")
            return self._get_fallback_diagnosis(service)
        
        try:
            headers = {
                "x-api-key": self.api_key,
                "content-type": "application/json",
                "anthropic-version": "2023-06-01"
            }
            
            data = {
                "model": "claude-3-7-sonnet-latest",
                "max_tokens": 1000,
                "messages": [
                    {
                        "role": "user", 
                        "content": f"""You are a Linux system administrator AI. Analyze these logs for service '{service}' 
which is currently showing status: {self.service_status[service]}.

SERVICE: {service}
CURRENT STATUS: {self.service_status[service]}

RECENT LOGS:
{logs}

First, diagnose the problem. Then, suggest a fix using ONE of these safe commands:
1. restart {service} - service {service} restart
2. start {service} - service {service} start

Format your response exactly like this:
DIAGNOSIS: [your diagnosis here]
COMMAND: [command name only - 'restart' or 'start']
EXPLANATION: [why this command will fix the issue]

Only suggest one of the listed commands. If you're unsure or none of these would help, respond with:
DIAGNOSIS: [your diagnosis here]
COMMAND: none
EXPLANATION: [why more complex intervention is needed]"""
                    }
                ]
            }
            
            # For demo purposes, if we can't reach the API, provide a canned response
            try:
                response = requests.post(self.api_url, headers=headers, json=data, timeout=10)
                if response.status_code == 200:
                    content = response.json()["content"][0]["text"]
                    logger.info(f"AI diagnosis for {service}: {content}")
                    return content
                else:
                    logger.error(f"API error: {response.status_code} - {response.text}")
                    # Fallback for demo
                    return self._get_fallback_diagnosis(service)
            except requests.exceptions.RequestException as e:
                logger.error(f"Could not connect to Claude API: {str(e)}")
                return self._get_fallback_diagnosis(service)
                
        except Exception as e:
            logger.error(f"Error diagnosing issue: {str(e)}")
            return self._get_fallback_diagnosis(service)
    
    def _get_fallback_diagnosis(self, service):
        """Fallback diagnosis for demo when API is unavailable"""
        if service == "ssh":
            return """DIAGNOSIS: The SSH service appears to be stopped or crashed
COMMAND: start
EXPLANATION: Starting the SSH service should restore SSH connectivity"""
        elif service == "apache2":
            return """DIAGNOSIS: The Apache web server is not running
COMMAND: start
EXPLANATION: Starting the Apache service will restore web server functionality"""
        else:
            return """DIAGNOSIS: Unknown service issue
COMMAND: none
EXPLANATION: Cannot determine appropriate fix for this service"""
    
    def parse_diagnosis(self, diagnosis):
        """Parse the AI diagnosis to extract command"""
        lines = diagnosis.split("\n")
        command = "none"
        
        for line in lines:
            if line.startswith("COMMAND:"):
                command = line.replace("COMMAND:", "").strip()
                break
                
        return command
    
    def apply_fix(self, service, command):
        """Apply the suggested fix"""
        if command == "none" or not command:
            logger.info(f"No fix applicable for {service}")
            return False
            
        # Map of safe commands
        safe_commands = {
            "restart": ["service", service, "restart"],
            "start": ["service", service, "start"]
        }
        
        if command not in safe_commands:
            logger.warning(f"Unsupported command: {command}")
            return False
            
        # Log the fix attempt
        logger.info(f"Attempting to fix {service} with command: {command}")
        
        # Apply the fix
        try:
            if not self.auto_fix:
                # In non-auto mode, just log what would have happened
                logger.info(f"Would execute: {' '.join(safe_commands[command])}")
                return True
                
            # Actually execute the command
            result = subprocess.run(
                safe_commands[command],
                capture_output=True, text=True, check=False
            )
            
            if result.returncode == 0:
                logger.info(f"Successfully fixed {service} with {command}")
                return True
            else:
                logger.error(f"Failed to fix {service}: {result.stderr}")
                return False
        except Exception as e:
            logger.error(f"Error applying fix to {service}: {str(e)}")
            return False
    
    def handle_failing_service(self, service):
        """Handle a failing service"""
        logger.info(f"Handling failing service: {service}")
        
        # Get service logs
        logs = self.get_service_logs(service)
        
        # Diagnose the issue
        diagnosis = self.diagnose_issue(service, logs)
        
        # Save diagnosis and logs for reference
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        with open(f"/var/log/self-healing/{service}_{timestamp}.log", "w") as f:
            f.write(f"=== SERVICE: {service} ===\n")
            f.write(f"=== STATUS: {self.service_status[service]} ===\n")
            f.write(f"=== LOGS ===\n{logs}\n\n")
            f.write(f"=== DIAGNOSIS ===\n{diagnosis}\n")
        
        # Parse and apply fix
        command = self.parse_diagnosis(diagnosis)
        success = self.apply_fix(service, command)
        
        # Update the log with the result
        with open(f"/var/log/self-healing/{service}_{timestamp}.log", "a") as f:
            f.write(f"\n=== FIX COMMAND: {command} ===\n")
            f.write(f"=== FIX RESULT: {'SUCCESS' if success else 'FAILED'} ===\n")
        
        return success
    
    def check_memory_status(self):
        """Check system memory status and return relevant information"""
        try:
            # Get memory info
            with open('/proc/meminfo') as f:
                mem_info = {}
                for line in f:
                    name, value = line.split(':')
                    mem_info[name.strip()] = int(value.strip().split()[0])  # Values are in kB
            
            total = mem_info['MemTotal']
            available = mem_info['MemAvailable']
            used_percent = ((total - available) / total) * 100

            # Get dmesg output for OOM events
            dmesg_output = subprocess.run(
                ["dmesg", "-T"], 
                capture_output=True, 
                text=True, 
                check=False
            ).stdout

            # Get top memory consuming processes
            ps_output = subprocess.run(
                ["ps", "aux", "--sort=-%mem"], 
                capture_output=True, 
                text=True, 
                check=False
            ).stdout

            return {
                'used_percent': used_percent,
                'dmesg': dmesg_output,
                'top_processes': ps_output,
                'is_critical': used_percent > self.memory_threshold
            }
        except Exception as e:
            logger.error(f"Error checking memory status: {str(e)}")
            return None

    def handle_memory_issue(self, memory_status):
        """Handle memory issues by analyzing and taking action"""
        if not memory_status:
            return False

        try:
            # Prepare system information for diagnosis
            system_info = f"""
Memory Usage: {memory_status['used_percent']:.2f}%

Recent dmesg output:
{memory_status['dmesg'][-1000:]}  # Last 1000 chars

Top Memory-Consuming Processes:
{memory_status['top_processes']}
"""
            # Get AI diagnosis
            diagnosis = self.diagnose_memory_issue(system_info)
            
            # Parse and execute recommended actions
            success = self.execute_memory_actions(diagnosis)
            
            # Log the event
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            with open(f"/var/log/self-healing/memory_{timestamp}.log", "w") as f:
                f.write(f"=== MEMORY ISSUE ===\n")
                f.write(f"=== SYSTEM INFO ===\n{system_info}\n")
                f.write(f"=== DIAGNOSIS ===\n{diagnosis}\n")
                f.write(f"=== RESULT ===\n{'SUCCESS' if success else 'FAILED'}\n")
            
            return success

        except Exception as e:
            logger.error(f"Error handling memory issue: {str(e)}")
            return False

    def diagnose_memory_issue(self, system_info):
        """Use Claude to diagnose memory issues and suggest actions"""
        if not self.api_key:
            return self._get_fallback_memory_diagnosis()

        try:
            headers = {
                "x-api-key": self.api_key,
                "content-type": "application/json",
                "anthropic-version": "2023-06-01"
            }
            
            data = {
                "model": "claude-3-7-sonnet-latest",
                "max_tokens": 1000,
                "messages": [{
                    "role": "user",
                    "content": f"""You are a Linux system administrator AI. Analyze this system memory information and suggest actions:

{system_info}

Suggest actions using ONLY these safe commands:
1. kill [PID] - Kill a specific process
2. service [name] stop - Stop a non-essential service

Format your response exactly like this:
DIAGNOSIS: [your diagnosis of the memory issue]
ACTIONS:
- [command with specific PID or service name]
- [another command if needed]
EXPLANATION: [why these actions will help]

Only suggest killing processes that are clearly non-essential (avoid system processes).
If no safe action is possible, respond with:
DIAGNOSIS: [your diagnosis]
ACTIONS: none
EXPLANATION: [why automated intervention is not safe]"""
                }]
            }

            response = requests.post(self.api_url, headers=headers, json=data, timeout=10)
            if response.status_code == 200:
                content = response.json()["content"][0]["text"]
                logger.info(f"AI memory diagnosis: {content}")
                return content
            else:
                logger.error(f"API error: {response.status_code} - {response.text}")
                return self._get_fallback_memory_diagnosis()

        except Exception as e:
            logger.error(f"Error getting memory diagnosis: {str(e)}")
            return self._get_fallback_memory_diagnosis()

    def _get_fallback_memory_diagnosis(self):
        """Fallback memory diagnosis when API is unavailable"""
        return """DIAGNOSIS: High memory usage detected
ACTIONS: none
EXPLANATION: Cannot safely determine which processes to terminate without AI analysis"""

    def execute_memory_actions(self, diagnosis):
        """Execute the recommended memory actions"""
        try:
            lines = diagnosis.split("\n")
            actions = []
            in_actions = False
            
            for line in lines:
                if line.startswith("ACTIONS:"):
                    in_actions = True
                    continue
                elif line.startswith("EXPLANATION:"):
                    break
                elif in_actions and line.strip().startswith("-"):
                    action = line.strip("- ").strip()
                    if action.lower() != "none":
                        actions.append(action)

            if not actions:
                logger.info("No memory actions to execute")
                return True

            success = True
            for action in actions:
                try:
                    if not self.auto_fix:
                        logger.info(f"Would execute: {action}")
                        continue

                    parts = action.split()
                    if parts[0] == "kill":
                        pid = int(parts[1])
                        subprocess.run(["kill", str(pid)], check=True)
                        logger.info(f"Killed process {pid}")
                    elif parts[0] == "service":
                        service_name = parts[1]
                        subprocess.run(["service", service_name, "stop"], check=True)
                        logger.info(f"Stopped service {service_name}")
                    else:
                        logger.warning(f"Unsupported action: {action}")
                        success = False
                except Exception as e:
                    logger.error(f"Error executing action '{action}': {str(e)}")
                    success = False

            return success

        except Exception as e:
            logger.error(f"Error executing memory actions: {str(e)}")
            return False

    def save_status(self):
        """Save current status to a file for the dashboard"""
        try:
            status = {
                'memory_usage': self.memory_status['used_percent'] if hasattr(self, 'memory_status') else 0,
                'service_status': self.service_status,
                'top_processes': self.memory_status['top_processes'] if hasattr(self, 'memory_status') else '',
                'timestamp': datetime.now().isoformat()
            }
            
            with open('/var/log/self-healing/status.json', 'w') as f:
                json.dump(status, f)
        except Exception as e:
            logger.error(f"Error saving status: {str(e)}")

    def run(self):
        """Main daemon loop"""
        logger.info("Starting self-healing daemon loop")
        
        while True:
            try:
                # Monitor all services
                self.monitor_services()
                
                # Check memory status
                memory_status = self.check_memory_status()
                self.memory_status = memory_status  # Store for status updates
                
                logger.info(f"Memory percentage used: {memory_status['used_percent']:.2f}%")
                if memory_status and memory_status['is_critical']:
                    logger.warning(f"Critical memory usage detected: {memory_status['used_percent']:.2f}%")
                    self.handle_memory_issue(memory_status)
                
                # Check for failing services
                for service, status in self.service_status.items():
                    if status != "active":
                        logger.info(f"Detected failing service: {service} (status: {status})")
                        self.handle_failing_service(service)
                
                # Save current status for dashboard
                self.save_status()
                
                # Sleep before next check
                time.sleep(10)  # Check every 10 seconds for demo
            except KeyboardInterrupt:
                logger.info("Daemon stopping due to keyboard interrupt")
                break
            except Exception as e:
                logger.error(f"Error in main loop: {str(e)}")
                time.sleep(10)  # Sleep and retry

def main():
    # Get API key from environment
    api_key = os.environ.get("CLAUDE_API_KEY")
    
    if not api_key:
        logger.warning("No API key provided. Set CLAUDE_API_KEY environment variable for AI diagnosis")
        
    daemon = SelfHealingDaemon(api_key=api_key, auto_fix=True)
    daemon.run()

if __name__ == "__main__":
    main()