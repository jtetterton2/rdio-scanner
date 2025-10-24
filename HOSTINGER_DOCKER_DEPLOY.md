# Deploying Rdio Scanner to Hostinger VPS with Docker

## Prerequisites

- Hostinger VPS with SSH access
- Docker installed on VPS
- Git installed on VPS
- Port 3000 (or custom) available

---

## Quick Start Commands

### 1. SSH into your Hostinger VPS

```bash
ssh root@your-hostinger-ip
# Or if using a non-root user:
ssh username@your-hostinger-ip
```

### 2. Install Docker (if not already installed)

```bash
# Update package index
apt-get update

# Install prerequisites
apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

# Add Docker repository
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Update package index again
apt-get update

# Install Docker
apt-get install -y docker-ce docker-ce-cli containerd.io

# Verify installation
docker --version

# Start Docker service
systemctl start docker
systemctl enable docker
```

### 3. Clone Your Repository

```bash
# Navigate to a suitable directory
cd /opt

# Clone your forked repository with security fixes
git clone https://github.com/jtetterton2/rdio-scanner.git

# Enter the directory
cd rdio-scanner
```

### 4. Build Docker Image

```bash
# Build the Docker image using the included Containerfile
docker build -t rdio-scanner:latest -f Containerfile .

# This will:
# - Build the Angular frontend
# - Build the Go backend
# - Create a minimal Alpine-based image (~50MB)
```

### 5. Create Data Directory

```bash
# Create a directory for persistent data
mkdir -p /opt/rdio-scanner-data

# Set permissions
chmod 755 /opt/rdio-scanner-data
```

### 6. Run the Container

```bash
# Run the container
docker run -d \
  --name rdio-scanner \
  --restart unless-stopped \
  -p 3000:3000 \
  -v /opt/rdio-scanner-data:/app/data \
  rdio-scanner:latest

# Check if container is running
docker ps

# View container logs (including the initial password!)
docker logs rdio-scanner
```

### 7. Get Initial Admin Password

```bash
# View logs to find the initial password
docker logs rdio-scanner 2>&1 | grep -A 3 "FIRST-TIME SETUP"

# You should see:
# ═══════════════════════════════════════════════════════════
#   FIRST-TIME SETUP DETECTED
#   Initial admin password: [22-character password]
#   WARNING: You MUST change this password on first login!
# ═══════════════════════════════════════════════════════════

# Save this password!
```

### 8. Access the Application

```bash
# The app should now be running at:
http://your-hostinger-ip:3000

# Admin interface at:
http://your-hostinger-ip:3000/admin
```

---

## Alternative: Using Docker Compose (Recommended)

Create a `docker-compose.yml` file:

```yaml
version: '3.8'

services:
  rdio-scanner:
    build:
      context: .
      dockerfile: Containerfile
    container_name: rdio-scanner
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - rdio-scanner-data:/app/data
    environment:
      - TZ=America/New_York  # Set your timezone
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  rdio-scanner-data:
    driver: local
```

Then run:

```bash
# Start with Docker Compose
docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down

# Restart
docker-compose restart
```

---

## Port Configuration

### Using Custom Port (e.g., 8080)

```bash
# Run on port 8080 instead of 3000
docker run -d \
  --name rdio-scanner \
  --restart unless-stopped \
  -p 8080:3000 \
  -v /opt/rdio-scanner-data:/app/data \
  rdio-scanner:latest
```

### Using Standard HTTP Port (80)

```bash
# Run on port 80 (requires root or privileged mode)
docker run -d \
  --name rdio-scanner \
  --restart unless-stopped \
  -p 80:3000 \
  -v /opt/rdio-scanner-data:/app/data \
  rdio-scanner:latest

# Access at: http://your-hostinger-ip
```

---

## SSL/HTTPS Setup with Nginx Reverse Proxy

### 1. Install Nginx

```bash
apt-get install -y nginx certbot python3-certbot-nginx
```

### 2. Create Nginx Configuration

```bash
cat > /etc/nginx/sites-available/rdio-scanner << 'EOF'
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket support
    location /ws {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
```

### 3. Enable Site and Get SSL Certificate

```bash
# Enable the site
ln -s /etc/nginx/sites-available/rdio-scanner /etc/nginx/sites-enabled/

# Test configuration
nginx -t

# Reload Nginx
systemctl reload nginx

# Get SSL certificate (replace with your domain)
certbot --nginx -d your-domain.com -d www.your-domain.com

# Certbot will automatically update the Nginx config for HTTPS
```

---

## Useful Docker Commands

### View Logs

```bash
# View all logs
docker logs rdio-scanner

# Follow logs in real-time
docker logs -f rdio-scanner

# View last 100 lines
docker logs --tail 100 rdio-scanner
```

### Restart Container

```bash
docker restart rdio-scanner
```

### Stop Container

```bash
docker stop rdio-scanner
```

### Remove Container

```bash
# Stop and remove container
docker stop rdio-scanner
docker rm rdio-scanner

# Remove image
docker rmi rdio-scanner:latest
```

### Update to Latest Code

```bash
# Pull latest changes
cd /opt/rdio-scanner
git pull origin master

# Rebuild image
docker build -t rdio-scanner:latest -f Containerfile .

# Stop old container
docker stop rdio-scanner
docker rm rdio-scanner

# Start new container
docker run -d \
  --name rdio-scanner \
  --restart unless-stopped \
  -p 3000:3000 \
  -v /opt/rdio-scanner-data:/app/data \
  rdio-scanner:latest

# Check logs for new password (if database was reset)
docker logs rdio-scanner
```

### Access Container Shell

```bash
# Access running container
docker exec -it rdio-scanner sh

# Navigate around
cd /app
ls -la
cat rdio-scanner.db

# Exit
exit
```

### View Container Stats

```bash
# Resource usage
docker stats rdio-scanner

# Detailed info
docker inspect rdio-scanner
```

---

## Database Backup

### Backup Database

```bash
# Create backup directory
mkdir -p /opt/rdio-scanner-backups

# Copy database from container
docker cp rdio-scanner:/app/data/rdio-scanner.db /opt/rdio-scanner-backups/rdio-scanner-$(date +%Y%m%d-%H%M%S).db

# Or if using volume
cp /opt/rdio-scanner-data/rdio-scanner.db /opt/rdio-scanner-backups/rdio-scanner-$(date +%Y%m%d-%H%M%S).db
```

### Restore Database

```bash
# Stop container
docker stop rdio-scanner

# Restore database
cp /opt/rdio-scanner-backups/rdio-scanner-YYYYMMDD-HHMMSS.db /opt/rdio-scanner-data/rdio-scanner.db

# Start container
docker start rdio-scanner
```

### Automated Backup Script

```bash
cat > /opt/backup-rdio-scanner.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/rdio-scanner-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p $BACKUP_DIR
docker cp rdio-scanner:/app/data/rdio-scanner.db $BACKUP_DIR/rdio-scanner-$TIMESTAMP.db
# Keep only last 7 days
find $BACKUP_DIR -name "rdio-scanner-*.db" -mtime +7 -delete
echo "Backup completed: rdio-scanner-$TIMESTAMP.db"
EOF

chmod +x /opt/backup-rdio-scanner.sh

# Add to crontab (daily at 2 AM)
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/backup-rdio-scanner.sh") | crontab -
```

---

## Firewall Configuration (UFW)

```bash
# Install UFW if not present
apt-get install -y ufw

# Allow SSH (important!)
ufw allow 22/tcp

# Allow HTTP
ufw allow 80/tcp

# Allow HTTPS
ufw allow 443/tcp

# Allow custom port (if using 3000)
ufw allow 3000/tcp

# Enable firewall
ufw enable

# Check status
ufw status
```

---

## Monitoring

### Check if Container is Running

```bash
# List running containers
docker ps

# Check container health
docker inspect --format='{{.State.Health.Status}}' rdio-scanner
```

### Monitor System Resources

```bash
# Install htop
apt-get install -y htop

# Run htop
htop

# Monitor Docker stats
docker stats rdio-scanner
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs for errors
docker logs rdio-scanner

# Check if port is already in use
netstat -tuln | grep 3000

# Try running in foreground to see errors
docker run --rm -it -p 3000:3000 rdio-scanner:latest
```

### Can't Access from Browser

```bash
# Check if container is running
docker ps

# Check firewall
ufw status

# Test from VPS
curl http://localhost:3000

# Check Nginx if using reverse proxy
systemctl status nginx
nginx -t
```

### Database Issues

```bash
# Check database file exists
docker exec rdio-scanner ls -la /app/data/

# Check permissions
docker exec rdio-scanner ls -la /app/data/rdio-scanner.db

# Reset database (will lose data!)
docker stop rdio-scanner
docker rm rdio-scanner
rm /opt/rdio-scanner-data/rdio-scanner.db
# Start container again - will create new DB with new password
```

---

## Complete Deployment Script

Save this as `deploy-rdio-scanner.sh`:

```bash
#!/bin/bash

set -e  # Exit on error

echo "=== Rdio Scanner Docker Deployment ==="

# Configuration
APP_DIR="/opt/rdio-scanner"
DATA_DIR="/opt/rdio-scanner-data"
CONTAINER_NAME="rdio-scanner"
IMAGE_NAME="rdio-scanner:latest"
PORT="3000"

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    systemctl start docker
    systemctl enable docker
fi

# Clone repository
if [ ! -d "$APP_DIR" ]; then
    echo "Cloning repository..."
    git clone https://github.com/jtetterton2/rdio-scanner.git $APP_DIR
else
    echo "Updating repository..."
    cd $APP_DIR
    git pull origin master
fi

cd $APP_DIR

# Create data directory
mkdir -p $DATA_DIR
chmod 755 $DATA_DIR

# Stop and remove old container if exists
if docker ps -a | grep -q $CONTAINER_NAME; then
    echo "Removing old container..."
    docker stop $CONTAINER_NAME || true
    docker rm $CONTAINER_NAME || true
fi

# Build image
echo "Building Docker image..."
docker build -t $IMAGE_NAME -f Containerfile .

# Run container
echo "Starting container..."
docker run -d \
  --name $CONTAINER_NAME \
  --restart unless-stopped \
  -p $PORT:3000 \
  -v $DATA_DIR:/app/data \
  $IMAGE_NAME

# Wait for container to start
sleep 5

# Check if running
if docker ps | grep -q $CONTAINER_NAME; then
    echo "✅ Container started successfully!"
    echo ""
    echo "=== IMPORTANT ==="
    echo "Retrieving initial admin password..."
    echo ""
    docker logs $CONTAINER_NAME 2>&1 | grep -A 3 "FIRST-TIME SETUP" || echo "No first-time setup message (database may already exist)"
    echo ""
    echo "Access the application at: http://$(hostname -I | awk '{print $1}'):$PORT"
    echo "Admin interface at: http://$(hostname -I | awk '{print $1}'):$PORT/admin"
else
    echo "❌ Container failed to start. Check logs:"
    docker logs $CONTAINER_NAME
    exit 1
fi
```

Make it executable and run:

```bash
chmod +x deploy-rdio-scanner.sh
./deploy-rdio-scanner.sh
```

---

## Summary

**Quick Deploy:**
```bash
# 1. SSH to Hostinger VPS
ssh root@your-hostinger-ip

# 2. Run one-line deployment
curl -fsSL https://raw.githubusercontent.com/jtetterton2/rdio-scanner/master/deploy-rdio-scanner.sh | bash

# 3. Note the displayed password
# 4. Access http://your-ip:3000
```

**That's it!** Your Rdio Scanner is now running with all Phase 1 security fixes applied.

---

## Next Steps

1. Change the admin password immediately
2. Configure your radio recorders to send audio to the server
3. Set up SSL with Nginx for HTTPS
4. Configure backups
5. Monitor logs and performance

For support, refer to:
- `SECURITY_FIXES_TESTING.md` - Security testing procedures
- `CHANGES_PHASE1.md` - What was fixed
- Official docs: `docs/` directory
