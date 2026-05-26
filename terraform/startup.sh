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

echo "[$(date)] Syncing private security components from parameter store..."
export GAME_SERVER_API_TOKEN=$(aws ssm get-parameter --name "/poker/server/api_token" --with-decryption --query "Parameter.Value" --output text --region us-east-1)

exec 3>&1

LOG_DIR="/home/ec2-user/logs"
mkdir -p "$LOG_DIR"

# Redirect stdout and stderr to the orchestrator log file, keeping a local copy for SSM to read from
exec > >(tee -a "$LOG_DIR/orchestrator.log") 2>&1
echo "[$(date +'%Y-%m-%dT%H:%M:%S')] Starting new game session request..."

MIN_PORT=12000
MAX_PORT=13000
SERVER_BIN="/home/ec2-user/poker_server.x86_64"
GAMES_TABLE_NAME="$1"
TARGET_GAME_ID="$2"
HOST_PLAYER_ID="$3"
BLIND_VALUE="$4"

# Find a free port for the new game instance
while :; do
    PORT=$(( (RANDOM % ($MAX_PORT - $MIN_PORT + 1)) + $MIN_PORT))
    (echo >/dev/tcp/localhost/$PORT) >/dev/null 2>&1 || break
done

echo "[$(date +'%Y-%m-%dT%H:%M:%S')] Found free port: $PORT"

echo "[$(date +'%Y-%m-%dT%H:%M:%S')] Spinning up Godot binary on port $PORT "
sudo -u ec2-user $SERVER_BIN --server --headless --port=$PORT --blind=$BLIND_VALUE > "$LOG_DIR/poker_$PORT.log" 2>&1 &

PID=$!
echo "[$(date +'%Y-%m-%dT%H:%M:%S')] Game server process started with PID: $PID"

# Disown the process so it detaches from this shell execution thread
disown $PID

# Update Dynamo with status so that our check api can return the details back
echo "[$(date +'%Y-%m-%dT%H:%M:%S')] Updating DynamoDB Game ID $${TARGET_GAME_ID} with Port $${PORT}..."

export AWS_DEFAULT_REGION="us-east-1"
export HOME="/home/ec2-user"

aws dynamodb update-item \
    --table-name "$${GAMES_TABLE_NAME}" \
    --key "{\"gameId\": {\"S\": \"$${TARGET_GAME_ID}\"}, \"hostPlayerId\": {\"S\": \"$${HOST_PLAYER_ID}\"}}" \
    --update-expression "SET port = :p, gameStatus = :s" \
    --expression-attribute-values "{\":p\": {\"S\": \"$${PORT}\"}, \":s\": {\"S\": \"ACTIVE\"}}" \
    --region us-east-1

# Clear file descriptors explicitly so the shell knows it can close cleanly
exec 3>&-
EOF

# Finalize file permissions
chmod +x /home/ec2-user/start_game_session.sh
if [ -f "/home/ec2-user/poker_server.x86_64" ]; then
    chmod +x /home/ec2-user/poker_server.x86_64
fi
chown -R ec2-user:ec2-user /home/ec2-user/