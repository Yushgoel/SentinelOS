## SentinelOS - A self-healing Linux system

Steps:

1. Create a `.env` file with your Anthropic API key.
2. Run `chmod +x launch.sh`
3. Run `./launch.sh`
4. Run `docker exec -it self-healing-demo /app/test-break.sh` to start and monitor logs
5. Run `docker exec -it self-healing-demo /app/break-service.sh` to break a service
6. Watch the logs to see the self-healing daemon fix the service

