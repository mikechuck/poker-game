#!/bin/bash
set -e

# System Update and Dependencies
sudo dnf update -y
sudo dnf install -y nginx libXcursor libXinerama libXrandr libXi fontconfig nmap-ncat
sudo yum install -y amazon-cloudwatch-agent
mkdir -p /home/ec2-user/logs

# Start the agent using the config stored in SSM
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c ssm:${cwAgentConfigName} \
    -s

# Download Files
aws s3 cp s3://${bucketName}/${s3Prefix} /home/ec2-user/ --recursive
cd /home/ec2-user

# Nginx setup
if [ -f "poker.conf" ]; then
sudo cp poker.conf /etc/nginx/conf.d/poker.conf
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl start nginx
fi
chmod +x ./poker_server.x86_64

# Create Session Starter
# Goal of this script: 
#  - free a port
#  - launch a new godot server process 
#  - register that new port as a path (/game/PORT) so that nginx can route requests to it
#  - report back to the launcher process (lambda function) what that new port is so it can save it and tell the user
cat << 'EOF' > /home/ec2-user/start_game_session.sh
#!/bin/bash
LOG_DIR="/home/ec2-user/logs"
mkdir -p "$LOG_DIR"
# Redirect stdout and stderr to the orchestrator log file, keeping a local copy for SSM to read from
exec > >(tee -a "$LOG_DIR/orchestrator.log") 2>&1
echo "[$(date +'%Y-%m-%dT%H:%M:%S')] Starting new game session request..."

MIN_PORT=12000
MAX_PORT=13000
SERVER_BIN="/home/ec2-user/poker_server.x86_64"

# Find a free port for the new game instance
while :; do
    PORT=$(( (RANDOM % ($MAX_PORT - $MIN_PORT + 1)) + $MIN_PORT))
    (echo >/dev/tcp/localhost/$PORT) >/dev/null 2>&1 || break
done

echo "[$(date +'%Y-%m-%dT%H:%M:%S')] Found free port: $PORT"

echo "[$(date +'%Y-%m-%dT%H:%M:%S')] Spinning up Godot binary on port $PORT with arguments: $@"
sudo -u ec2-user $SERVER_BIN --server --headless --port=$PORT "$@" > "$LOG_DIR/poker_$PORT.log" 2>&1 &

PID=$!
echo "[$(date +'%Y-%m-%dT%H:%M:%S')] Game server process started with PID: $PID"

echo $PORT >&3
EOF

#Adjusting the script to preserve a file descriptor path for the clean port callback before saving the file.
sed -i 's/>\&3/>\&1/g' /home/ec2-user/start_game_session.sh
# Wrap the script contents inside a descriptor block so 'echo $PORT' handles clean returns
sed -i '1s/^/exec 3>\&1\n/' /home/ec2-user/start_game_session.sh

# Finalize file permissions
chmod +x /home/ec2-user/start_game_session.sh
chown -R ec2-user:ec2-user /home/ec2-user/logs