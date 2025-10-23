#!/bin/bash
set -e

# BBGO EC2 Instance Initialization Script
# This script runs automatically when the EC2 instance first launches

exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=========================================="
echo "BBGO XMaker EC2 Setup Started"
echo "Time: $(date)"
echo "=========================================="

# Update system packages
echo "Updating system packages..."
yum update -y

# Install dependencies
echo "Installing Git, PostgreSQL client..."
yum install -y git postgresql15

# Install Go 1.21
echo "Installing Go 1.21..."
GO_VERSION="1.21.5"
cd /tmp
wget -q https://go.dev/dl/go$${GO_VERSION}.linux-amd64.tar.gz
rm -rf /usr/local/go
tar -C /usr/local -xzf go$${GO_VERSION}.linux-amd64.tar.gz

# Configure Go environment for all users
cat > /etc/profile.d/go.sh <<'EOF'
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
EOF

# Load Go environment for current session
source /etc/profile.d/go.sh

# Verify Go installation
/usr/local/go/bin/go version

# Clone BBGO repository
echo "Cloning BBGO repository..."
cd /home/ec2-user
if [ ! -d "bbgo" ]; then
  sudo -u ec2-user git clone https://github.com/c9s/bbgo.git
fi

# Build BBGO (slim version without web UI)
echo "Building BBGO..."
cd /home/ec2-user/bbgo
sudo -u ec2-user /usr/local/go/bin/go run ./cmd/bbgo version || true
sudo -u ec2-user make bbgo-slim

# Move binary to system path
echo "Installing BBGO binary..."
mv bbgo-slim /usr/local/bin/bbgo
chmod +x /usr/local/bin/bbgo

# Create production directory structure
echo "Creating production directories..."
sudo -u ec2-user mkdir -p /home/ec2-user/bbgo-prod/{config,var/data,logs}

# Create environment file template (user will fill in manually)
echo "Creating environment file template..."
cat > /home/ec2-user/.env.local.template <<'EOF'
# Database Configuration (create RDS manually first)
# DB_DRIVER=postgres
# DB_DSN=host=YOUR_RDS_ENDPOINT port=5432 user=YOUR_DB_USERNAME password=YOUR_DB_PASSWORD dbname=YOUR_DB_NAME sslmode=require

# Exchange API Keys - Binance
BINANCE_API_KEY=your_binance_api_key
BINANCE_API_SECRET=your_binance_api_secret

# Exchange API Keys - MAX
MAX_API_KEY=your_max_api_key
MAX_API_SECRET=your_max_api_secret

# Optional: Telegram Notifications
# TELEGRAM_BOT_TOKEN=your_telegram_bot_token
# TELEGRAM_CHAT_ID=your_telegram_chat_id
EOF

chown ec2-user:ec2-user /home/ec2-user/.env.local.template
chmod 644 /home/ec2-user/.env.local.template

echo ""
echo "=========================================="
echo "IMPORTANT: Setup Instructions"
echo "=========================================="
echo "1. Create RDS database through AWS Console (optional)"
echo "2. Copy template: cp ~/.env.local.template ~/.env.local"
echo "3. Edit .env.local with RDS endpoint and API keys: nano ~/.env.local"
echo "4. Set permissions: chmod 600 ~/.env.local"
echo "5. If using database, run migrations: bbgo-migrate"
echo "=========================================="
echo ""

# Create XMaker configuration
echo "Creating XMaker strategy configuration..."
cat > /home/ec2-user/bbgo-prod/config/xmaker.yaml <<'YAML_EOF'
---
notifications:
  switches:
    trade: true
    orderUpdate: true
    submitOrder: false

persistence:
  json:
    directory: var/data

logging:
  trade: true
  order: true

sessions:
  binance:
    exchange: binance
    envVarPrefix: binance

  max:
    exchange: max
    envVarPrefix: max

crossExchangeStrategies:
- xmaker:
    symbol: "ETHUSDT"
    sourceExchange: binance
    makerExchange: max

    # Timing
    updateInterval: 2s
    hedgeInterval: 10s

    # Profit margins
    margin: 0.005
    bidMargin: 0.005
    askMargin: 0.005

    # Order configuration
    quantity: 0.01
    quantityMultiplier: 1.5
    numLayers: 2

    # Risk controls
    maxExposurePosition: 0.1

    # Circuit breaker
    circuitBreaker:
      enabled: true
      maximumConsecutiveLossTimes: 5
      maximumConsecutiveTotalLoss: 50.0
      maximumLossPerRound: 15.0
      haltDuration: "1h"
      maximumHaltTimes: 2
YAML_EOF

chown ec2-user:ec2-user /home/ec2-user/bbgo-prod/config/xmaker.yaml

# Note: RDS will be created manually through AWS Console
echo "RDS database not included in Terraform deployment"
echo "You will need to create RDS manually and update .env.local with the endpoint"

# Create helpful scripts for running BBGO
echo "Creating helper scripts..."
cat > /home/ec2-user/bbgo-run.sh <<'SCRIPT_EOF'
#!/bin/bash
# Run BBGO with your configuration
cd /home/ec2-user/bbgo-prod

# Check if .env.local exists
if [ ! -f /home/ec2-user/.env.local ]; then
    echo "ERROR: .env.local not found!"
    echo "Please create it from the template:"
    echo "  cp ~/.env.local.template ~/.env.local"
    echo "  nano ~/.env.local"
    echo "  chmod 600 ~/.env.local"
    exit 1
fi

# Load environment variables
source /home/ec2-user/.env.local

# Run BBGO
exec /usr/local/bin/bbgo run --config /home/ec2-user/bbgo-prod/config/xmaker.yaml
SCRIPT_EOF

cat > /home/ec2-user/bbgo-migrate.sh <<'SCRIPT_EOF'
#!/bin/bash
# Run database migrations
if [ ! -f /home/ec2-user/.env.local ]; then
    echo "ERROR: .env.local not found!"
    exit 1
fi

source /home/ec2-user/.env.local
cd /home/ec2-user/bbgo
/usr/local/bin/bbgo migrate
SCRIPT_EOF

cat > /home/ec2-user/bbgo-update.sh <<'SCRIPT_EOF'
#!/bin/bash
# Update BBGO from GitHub
echo "Updating BBGO from GitHub..."
cd /home/ec2-user/bbgo
git pull
echo "Rebuilding BBGO..."
make bbgo-slim
sudo mv bbgo-slim /usr/local/bin/bbgo
echo "Update complete!"
SCRIPT_EOF

chmod +x /home/ec2-user/bbgo-*.sh
chown ec2-user:ec2-user /home/ec2-user/bbgo-*.sh

# Add helpful aliases to .bashrc
cat >> /home/ec2-user/.bashrc <<'BASHRC_EOF'

# BBGO Aliases
alias bbgo-run='~/bbgo-run.sh'
alias bbgo-migrate='~/bbgo-migrate.sh'
alias bbgo-update='~/bbgo-update.sh'
alias bbgo-cd='cd ~/bbgo'
alias bbgo-prod='cd ~/bbgo-prod'
BASHRC_EOF

# Create welcome message
cat > /etc/motd <<'MOTD_EOF'
========================================
BBGO XMaker Trading Bot
========================================

SETUP REQUIRED:
  1. Create RDS database (optional - for trade history):
     - Go to AWS Console > RDS
     - Create PostgreSQL database in private subnet
     - Allow access from EC2 security group

  2. Create .env.local:
     cp ~/.env.local.template ~/.env.local
     nano ~/.env.local
     chmod 600 ~/.env.local

  3. Update config (optional):
     nano ~/bbgo-prod/config/xmaker.yaml

  4. Run database migrations (if using RDS):
     bbgo-migrate

  5. Run BBGO:
     bbgo-run

Quick Commands:
  bbgo-run      - Run BBGO with your config
  bbgo-migrate  - Run database migrations
  bbgo-update   - Update BBGO from GitHub
  bbgo-cd       - Go to BBGO source directory
  bbgo-prod     - Go to production directory

Files:
  Config:  ~/bbgo-prod/config/xmaker.yaml
  Env:     ~/.env.local (create from template)
  Source:  ~/bbgo/

Database (if created):
  psql -h [rds-endpoint] -U [username] -d bbgo

For help: https://github.com/c9s/bbgo
========================================
MOTD_EOF

echo "=========================================="
echo "BBGO XMaker EC2 Setup Completed"
echo "Time: $(date)"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. (Optional) Create RDS database through AWS Console"
echo "2. Create .env.local with your RDS endpoint and API keys"
echo "3. Run: bbgo-migrate (if using database)"
echo "4. Run: bbgo-run"
echo ""
echo "=========================================="
