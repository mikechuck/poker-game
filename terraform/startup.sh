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

# We only grab base environment configs like nginx config sheets here, not the game files
aws s3 cp s3://${bucketName}/${s3Prefix} /home/ec2-user/ --recursive --exclude "*" --include "poker.conf"
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
cat << EOF > /home/ec2-user/start_game_session.sh
#!/bin/bash

set -e

# Setup a local file log loop just for the orchestration steps
LOG_DIR="/home/ec2-user/logs"
mkdir -p "\$LOG_DIR"
exec > >(tee -a "\$LOG_DIR/orchestrator.log") 2>&1

echo "[Startup] Starting new game session request..."

MIN_PORT=12000
MAX_PORT=13000
SERVER_BIN="/home/ec2-user/poker_server.x86_64"
GAMES_TABLE_NAME="\$1"
TARGET_GAME_ID="\$2"
HOST_PLAYER_ID="\$3"
BLIND_VALUE="\$4"

# Grab api token so game server instance can talk to our apis
export GAME_SERVER_API_TOKEN=\$(aws ssm get-parameter --name "/poker/server/api_token" --with-decryption --query "Parameter.Value" --output text --region us-east-1)
export AWS_DEFAULT_REGION="us-east-1"
export HOME="/home/ec2-user"

# 🟩 STEP 1: Pull the latest fresh server engine builds directly from S3 at launch time
echo "[Startup] Downloading fresh server binaries from S3..."
aws s3 cp s3://\${bucketName}/\${s3Prefix} /home/ec2-user/ --recursive --exclude "*" --include "poker_server*" --include "shared/*"

# 🟩 STEP 2: Explicitly clear permissions so ec2-user can run it even if SSM invoked as root
chmod +x "\$SERVER_BIN"
chown -R ec2-user:ec2-user /home/ec2-user

# Find a free port for the new game instance
while :; do
    PORT=\$(( (RANDOM % (\$MAX_PORT - \$MIN_PORT + 1)) + \$MIN_PORT ))
    nc -z localhost \$PORT && CONTINUE=true || CONTINUE=false
    if [ "\$CONTINUE" = false ]; then
        break
    fi
done

echo "[Startup] Selected available port: \$PORT"

# Ensure wide open permissions for directory drops
chmod 777 "\$LOG_DIR"
cd /home/ec2-user

# Write the file directly to the agent's configuration directory using sudo tee
sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/poker_\$PORT_\$TARGET_GAME_ID.json > /dev/null << DYNCFG
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/home/ec2-user/logs/poker_\$PORT_\$TARGET_GAME_ID.log",
            "log_group_name": "/apps/poker-game",
            "log_stream_name": "{instance_id}-poker_\$PORT_\$TARGET_GAME_ID",
            "retention_in_days": -1
          }
        ]
      }
    }
  }
}
DYNCFG

echo "[Startup] Appending new log tracking rule for port \$PORT..."

sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a append-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/poker_\$PORT_\$TARGET_GAME_ID.json \
    -s

# Execute the binary explicitly running context dropped to 'ec2-user'
echo "[Startup] Detaching poker server engine process..."
sudo -u ec2-user -H nohup "\$SERVER_BIN" --headless --gameId="\$TARGET_GAME_ID" --port="\$PORT" --blind="\$BLIND_VALUE" --apiToken="\$GAME_SERVER_API_TOKEN" > "/home/ec2-user/logs/poker_\$PORT_\$TARGET_GAME_ID.log" 2>&1 < /dev/null &

PID=\$!
echo "[Startup] Game server process successfully detached with PID: \$PID on port \$PORT"
echo "[Startup] Game initialization complete!"
EOF

# Finalize orchestrator script permissions
chmod +x /home/ec2-user/start_game_session.sh
chown -R ec2-user:ec2-user /home/ec2-user