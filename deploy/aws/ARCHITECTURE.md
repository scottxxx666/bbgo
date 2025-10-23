# BBGO AWS Deployment Architecture

## Overview

This document describes the secure AWS architecture for deploying BBGO XMaker strategy using AWS Free Tier resources for 1 year.

## Architecture Diagram

```
Internet
    │
    │ (SSH only from your IP)
    ↓
┌─────────────────── VPC (10.0.0.0/16) ────────────────────┐
│                                                            │
│  ┌─── Public Subnet (10.0.1.0/24) ───┐                  │
│  │                                     │                  │
│  │  ┌─────────────────────┐           │                  │
│  │  │   EC2 t2.micro      │           │                  │
│  │  │   - BBGO binary     │           │                  │
│  │  │   - Git + Go        │           │                  │
│  │  │   - SSH (22)        │           │                  │
│  │  │   - Elastic IP      │           │                  │
│  │  └──────┬──────────────┘           │                  │
│  │         │                           │                  │
│  └─────────┼───────────────────────────┘                  │
│            │                                               │
│            │ (Internal VPC communication)                  │
│            ↓                                               │
│  ┌─── Private Subnet 1 (10.0.2.0/24) ─┐                  │
│  │                                      │                  │
│  │  ┌──────────────────────┐           │                  │
│  │  │  Aurora PostgreSQL   │           │                  │
│  │  │  db.t3.micro         │           │                  │
│  │  │  - NO Public Access  │           │                  │
│  │  │  - Port 5432         │           │                  │
│  │  │  - Encrypted         │           │                  │
│  │  └──────────────────────┘           │                  │
│  │                                      │                  │
│  │  ┌──────────────────────┐           │                  │
│  │  │  ElastiCache Redis   │           │                  │
│  │  │  cache.t2.micro      │           │                  │
│  │  │  - NO Public Access  │           │                  │
│  │  │  - Port 6379         │           │                  │
│  │  │  - Encrypted         │           │                  │
│  │  └──────────────────────┘           │                  │
│  │                                      │                  │
│  └──────────────────────────────────────┘                  │
│                                                            │
│  ┌─── Private Subnet 2 (10.0.3.0/24) ─┐                  │
│  │  (Aurora requires multi-AZ)         │                  │
│  └──────────────────────────────────────┘                  │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

## Components

### 1. VPC (Virtual Private Cloud)
- **CIDR Block**: 10.0.0.0/16
- **DNS Hostnames**: Enabled
- **DNS Resolution**: Enabled

### 2. Subnets

#### Public Subnet
- **CIDR**: 10.0.1.0/24
- **Availability Zone**: us-east-1a (configurable)
- **Resources**: EC2 instance
- **Internet Access**: Via Internet Gateway

#### Private Subnet 1
- **CIDR**: 10.0.2.0/24
- **Availability Zone**: us-east-1a
- **Resources**: Aurora primary, ElastiCache
- **Internet Access**: None

#### Private Subnet 2
- **CIDR**: 10.0.3.0/24
- **Availability Zone**: us-east-1b
- **Resources**: Aurora replica (multi-AZ requirement)
- **Internet Access**: None

### 3. Security Groups

#### EC2 Security Group (`sg-ec2-bbgo`)

**Inbound Rules:**
| Type | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| SSH | TCP | 22 | Your IP/32 | SSH access from your IP only |

**Outbound Rules:**
| Type | Protocol | Port | Destination | Description |
|------|----------|------|-------------|-------------|
| PostgreSQL | TCP | 5432 | sg-rds-aurora | Connect to Aurora |
| Custom TCP | TCP | 6379 | sg-redis | Connect to ElastiCache |
| HTTPS | TCP | 443 | 0.0.0.0/0 | Exchange API calls |
| HTTP | TCP | 80 | 0.0.0.0/0 | Exchange API calls (fallback) |

#### Aurora Security Group (`sg-rds-aurora`)

**Inbound Rules:**
| Type | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| PostgreSQL | TCP | 5432 | sg-ec2-bbgo | Only allow EC2 |

**Outbound Rules:**
- None (database doesn't need outbound access)

#### ElastiCache Security Group (`sg-redis`)

**Inbound Rules:**
| Type | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| Custom TCP | TCP | 6379 | sg-ec2-bbgo | Only allow EC2 |

**Outbound Rules:**
- None

### 4. Compute Resources

#### EC2 Instance
- **Type**: t2.micro (1 vCPU, 1GB RAM)
- **AMI**: Amazon Linux 2023
- **Storage**: 20GB gp3 EBS (encrypted)
- **Elastic IP**: Yes (static public IP)
- **Free Tier**: 750 hours/month for 12 months

#### Software Stack:
- Go 1.21+
- Git
- BBGO (compiled slim version)
- Systemd service for auto-restart

### 5. Database

#### Aurora PostgreSQL
- **Instance Class**: db.t3.micro
- **Engine**: Aurora PostgreSQL 15.4 compatible
- **Storage**: Auto-scaling, starts at 10GB
- **Multi-AZ**: Yes (for free tier compatibility)
- **Public Access**: NO
- **Encryption**: Enabled (at rest)
- **Backup**: 7-day retention
- **Free Tier**: 750 hours/month for 12 months

### 6. Cache

#### ElastiCache Redis
- **Node Type**: cache.t3.micro (512MB memory)
- **Engine**: Redis 7.x
- **Replication**: None (single node for cost savings)
- **Encryption**: In-transit enabled
- **Public Access**: NO
- **Free Tier**: 750 hours/month for 12 months

## Security Features

### Network Security
1. **Private Subnets**: Aurora and Redis have no public internet access
2. **Security Group Isolation**: Only EC2 can access databases
3. **IP Whitelisting**: SSH restricted to specific IP addresses
4. **VPC Isolation**: Resources isolated from other AWS accounts

### Data Security
1. **Encryption at Rest**: Aurora and EBS volumes encrypted
2. **Encryption in Transit**: Redis and Aurora use TLS
3. **Secrets Management**: API keys stored in environment variables (not in code)
4. **IAM Roles**: EC2 uses IAM role for AWS service access

### Access Control
1. **SSH Key Authentication**: No password authentication
2. **Minimal Port Exposure**: Only SSH (22) exposed to internet
3. **Least Privilege**: Security groups follow principle of least privilege
4. **No Direct DB Access**: Databases not accessible from internet

### Monitoring & Logging
1. **VPC Flow Logs**: Track all network traffic (optional, costs apply)
2. **CloudTrail**: Audit all API calls (optional, costs apply)
3. **CloudWatch Logs**: Application logs from EC2
4. **BBGO Logs**: Strategy execution logs on disk

## Data Flow

### Trading Flow
```
1. EC2 BBGO Process
   ↓ (Internal VPC)
2. ElastiCache Redis (read/write state)
   ↓
3. EC2 BBGO Process
   ↓ (Internal VPC)
4. Aurora MySQL (persist trades)
   ↓
5. EC2 BBGO Process
   ↓ (HTTPS to Internet)
6. Exchange APIs (Binance, MAX, etc.)
```

### Deployment Flow
```
1. Developer → SSH → EC2 (your IP only)
2. EC2 → Git Pull → GitHub
3. EC2 → Build BBGO → Local binary
4. EC2 → Systemd → Start BBGO service
5. BBGO → Connect → Redis (internal)
6. BBGO → Connect → Aurora (internal)
7. BBGO → Connect → Exchange APIs (internet)
```

## Cost Breakdown (Free Tier - First 12 Months)

| Resource | Specification | Usage | Free Tier Limit | Monthly Cost |
|----------|---------------|-------|-----------------|--------------|
| EC2 t2.micro | 1 instance | 730 hours | 750 hours | $0 |
| Aurora db.t3.micro | 1 instance | 730 hours | 750 hours | $0 |
| ElastiCache cache.t2.micro | 1 instance | 730 hours | 750 hours | $0 |
| EBS gp3 | 20GB | 20GB | 30GB | $0 |
| Data Transfer Out | Estimated | 10-15GB | 100GB | $0 |
| Elastic IP | 1 IP attached | Always attached | 1 free | $0 |
| **Total** | | | | **$0/month** |

### After Free Tier (Month 13+)

Estimated monthly cost (us-east-1):
- EC2 t2.micro: ~$8.47
- Aurora db.t3.micro: ~$28.80
- ElastiCache cache.t2.micro: ~$12.24
- EBS 20GB: ~$2.00
- **Total: ~$51.51/month**

### Update Procedure
```bash
# SSH to EC2
ssh -i key.pem ec2-user@your-elastic-ip

# Stop service
sudo systemctl stop bbgo

# Update code
cd ~/bbgo
git pull
make bbgo-slim
sudo mv bbgo-slim /usr/local/bin/bbgo

# Start service
sudo systemctl start bbgo

# Verify
sudo systemctl status bbgo
```

## Terraform Deployment

All infrastructure is defined as Infrastructure as Code (IaC) using Terraform.

### Files
- `main.tf`: Main infrastructure definitions
- `variables.tf`: Configuration variables
- `outputs.tf`: Output values after deployment
- `terraform.tfvars`: Your specific values (not committed to Git)
- `user-data.sh`: EC2 initialization script

### Deployment Commands
```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy infrastructure
terraform apply

# Destroy infrastructure
terraform destroy
```

## Security Checklist

Before deploying to production:

- [ ] Change default database passwords
- [ ] Set up strong API keys with minimal permissions
- [ ] Restrict SSH security group to your specific IP
- [ ] Enable CloudTrail for audit logging
- [ ] Enable VPC Flow Logs
- [ ] Set up CloudWatch alarms for critical metrics
- [ ] Configure automated backups
- [ ] Test disaster recovery procedures
- [ ] Enable MFA on AWS account
- [ ] Review IAM policies and permissions
- [ ] Set up budget alerts
- [ ] Document incident response procedures

## Troubleshooting

### Cannot SSH to EC2
- Check security group allows your IP
- Verify Elastic IP is attached
- Check EC2 instance is running
- Verify SSH key permissions: `chmod 400 key.pem`

### BBGO Cannot Connect to Aurora
- Check security group `sg-rds-aurora` allows `sg-ec2-bbgo`
- Verify Aurora endpoint in environment variables
- Check Aurora is in "Available" state
- Test connection: `mysql -h endpoint -u admin -p`

### BBGO Cannot Connect to Redis
- Check security group `sg-redis` allows `sg-ec2-bbgo`
- Verify Redis endpoint in config
- Check Redis cluster is "Available"
- Test connection: `redis-cli -h endpoint ping`

### Out of Disk Space
- Check disk usage: `df -h`
- Clean old logs: `find ~/bbgo-prod/logs -type f -mtime +7 -delete`
- Check database size: `du -sh ~/bbgo-prod/var/`

## References

- [BBGO Documentation](https://github.com/c9s/bbgo)
- [XMaker Strategy README](../../pkg/strategy/xmaker/README.md)
- [AWS Free Tier](https://aws.amazon.com/free/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Support

For issues and questions:
- GitHub Issues: https://github.com/c9s/bbgo/issues
- Telegram: @bbgo_intl
