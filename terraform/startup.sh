#!/bin/bash
set -e

# System Update and Dependencies
sudo dnf update -y
sudo dnf install -y nginx libXcursor libXinerama libXrandr libXi fontconfig nmap-ncat
mkdir -p /home/ec2-user/logs

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
MIN_PORT=12000
MAX_PORT=13000
SERVER_BIN="/home/ec2-user/poker_server.x86_64"
LOG_DIR="/home/ec2-user/logs"
while :; do
PORT=$(( (RANDOM % ($MAX_PORT - $MIN_PORT + 1)) + $MIN_PORT))
(echo >/dev/tcp/localhost/$PORT) >/dev/null 2>&1 || break
done
sudo -u ec2-user $SERVER_BIN --server --headless --port=$PORT "$@" > "$LOG_DIR/poker_$PORT.log" 2>&1 &
echo $PORT
EOF

# Finalize file permissions
chmod +x /home/ec2-user/start_game_session.sh
chown ec2-user:ec2-user /home/ec2-user/logs