## SentinelOS - A self-healing Linux system

Steps:

1. Create a `.env` file with your Anthropic API key.
2. Run `chmod +x launch.sh`
3. Run `./launch.sh`
4. Run `docker exec -it self-healing-demo /app/test-break.sh` to start and monitor logs
5. Run `docker exec -it self-healing-demo /app/break-service.sh` to break a service
6. Watch the logs to see the self-healing daemon fix the service

### Advanced VPN Tests

7. Run `docker exec -it self-healing-demo /app/break-vpn.sh` to break the VPN connection
8. Run `docker exec -it self-healing-demo /app/break-vpn-firewall.sh` to break the VPN using a firewall kill-switch
9. Run `docker exec -it self-healing-demo /app/test-vpn-firewall-fix.sh` to test the VPN firewall kill-switch fix

The firewall kill-switch test demonstrates an advanced self-healing scenario where:
- The VPN is broken by firewall rules that prevent normal reconnection
- The standard fixes fail to resolve the issue
- The system identifies the firewall problem by analyzing logs
- Claude is asked for an advanced solution that includes flushing the firewall rules
- The system implements the solution and properly restores the VPN

