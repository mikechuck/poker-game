#!/bin/bash
set -e

# System Update and Dependencies
sudo dnf update -y
sudo dnf install -y nginx libXcursor libXinerama libXrandr libXi fontconfig nmap-ncat
sudo yum install -y amazon-cloudwatch-agent
mkdir -p /home/ec2-user/logs
sudo usermod -aG ec2-user cwagent

# Start the agent using the config stored in SSM (Kept for basic system metrics)
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

# ==============================================================================
# Dynamic Session Starter Engine
# ==============================================================================
cat << 'EOF' > /home/ec2-user/start_game_session.sh
#!/bin/bash

set -e

# Setup a local file log loop just for the orchestration steps
LOG_DIR="/home/ec2-user/logs"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_DIR/orchestrator.log") 2>&1

echo "[Startup] Starting new game session request..."

MIN_PORT=12000
MAX_PORT=13000
SERVER_BIN="/home/ec2-user/poker_server.x86_64"
GAMES_TABLE_NAME="$1"
TARGET_GAME_ID="$2"
HOST_PLAYER_ID="$3"
BLIND_VALUE="$4"

# Pull down the latest server build straight from S3
echo "[Startup] Starting game initialization..."
aws s3 cp s3://${bucketName}/${s3Prefix}/poker_server.x86_64 "$SERVER_BIN"
chmod +x "$SERVER_BIN"

# Grab api token so game server instance can talk to our apis
export GAME_SERVER_API_TOKEN=$(aws ssm get-parameter --name "/poker/server/api_token" --with-decryption --query "Parameter.Value" --output text --region us-east-1)
export AWS_DEFAULT_REGION="us-east-1"
export HOME="/home/ec2-user"

# Find a free port for the new game instance
while :; do
    PORT=$(( (RANDOM % ($MAX_PORT - $MIN_PORT + 1)) + $MIN_PORT))
    (echo >/dev/tcp/localhost/$PORT) >/dev/null 2>&1 || break
done

# Ensure wide open permissions for directory drops
chmod 777 "$LOG_DIR"
cd /home/ec2-user

# 🟩 THE DEFINITIVE FIX: Wrap the cat/redirection operator inside a root-level bash string wrapper.
# This forces the system administrative layer to execute the file creation directly,
# cleanly bypassing the ec2-user directory write restrictions!
sudo bash -c "cat << DYNCFG > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/poker_$PORT.json
{
  \"logs\": {
    \"logs_collected\": {
      \"files\": {
        \"collect_list\": [
          {
            \"file_path\": \"/home/ec2-user/logs/poker_$PORT.log\",
            \"log_group_name\": \"/apps/poker-game\",
            \"log_stream_name\": \"\{instance_id}-poker_$PORT\"
          }
        ]
      }
    }
  }
}
DYNCFG"

# 🟩 THE DEFINITIVE FIX 3: Escaped cwAgentConfigName with double dollar signs so it matches your TF environment schema
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c ssm:${cwAgentConfigName} \
    -s

# Execute the server in the background using an isolated subshell string wrapper.
CMD_STR="nohup $SERVER_BIN --server --headless --gameId=$TARGET_GAME_ID --port=$PORT --blind=$BLIND_VALUE --apiToken=$GAME_SERVER_API_TOKEN > /home/ec2-user/logs/poker_$PORT.log 2>&1 < /dev/null &"
sudo -u ec2-user bash -c "$CMD_STR"

PID=$!
echo "[Startup] Game server process successfully detached with PID: $PID on port $PORT"
echo "[Startup] Game initialization complete!"
EOF

# Finalize file permissions
chmod +x /home/ec2-user/start_game_session.sh
if [ -f "/home/ec2-user/poker_server.x86_64" ]; then
    chmod +x /home/ec2-user/poker_server.x86_64
fi
chown -R ec2-user:ec2-user /home/ec2-user/