terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "BBGO"
      Strategy    = "XMaker"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "bbgo" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "bbgo" {
  vpc_id = aws_vpc.bbgo.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnet (for EC2)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.bbgo.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
    Tier = "Public"
  }
}

# Private Subnet 1 (for Aurora & ElastiCache)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.bbgo.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-private-subnet-1"
    Tier = "Private"
  }
}

# Private Subnet 2 (Aurora requires multi-AZ)
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.bbgo.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.project_name}-private-subnet-2"
    Tier = "Private"
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.bbgo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bbgo.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Route Table Association for Public Subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group for EC2
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for BBGO EC2 instance"
  vpc_id      = aws_vpc.bbgo.id

  # Inbound: SSH from your IP only
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Outbound: Allow all (will be restricted by RDS/Redis security groups)
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

# Security Group for Aurora
# Commented out - RDS will be created manually through AWS Console
# resource "aws_security_group" "rds" {
#   name        = "${var.project_name}-rds-sg"
#   description = "Security group for Aurora PostgreSQL"
#   vpc_id      = aws_vpc.bbgo.id
#
#   # Inbound: PostgreSQL from EC2 only
#   ingress {
#     description     = "PostgreSQL from EC2"
#     from_port       = 5432
#     to_port         = 5432
#     protocol        = "tcp"
#     security_groups = [aws_security_group.ec2.id]
#   }
#
#   tags = {
#     Name = "${var.project_name}-rds-sg"
#   }
# }

# Redis will run locally on EC2 - no separate security group needed

# DB Subnet Group for Aurora
# Commented out - RDS will be created manually through AWS Console
# resource "aws_db_subnet_group" "aurora" {
#   name       = "${var.project_name}-db-subnet-group"
#   subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]
#
#   tags = {
#     Name = "${var.project_name}-db-subnet-group"
#   }
# }

# Aurora PostgreSQL Cluster
# Commented out - RDS will be created manually through AWS Console
# resource "aws_rds_cluster" "bbgo" {
#   cluster_identifier      = "${var.project_name}-cluster"
#   engine                  = "aurora-postgresql"
#   engine_version          = "15.4"
#   database_name           = var.db_name
#   master_username         = var.db_username
#   master_password         = var.db_password
#   db_subnet_group_name    = aws_db_subnet_group.aurora.name
#   vpc_security_group_ids  = [aws_security_group.rds.id]
#   skip_final_snapshot     = true
#   backup_retention_period = 7
#   preferred_backup_window = "03:00-04:00"
#   storage_encrypted       = true
#   port                    = 5432
#
#   tags = {
#     Name = "${var.project_name}-aurora-cluster"
#   }
# }

# Aurora PostgreSQL Instance
# Commented out - RDS will be created manually through AWS Console
# resource "aws_rds_cluster_instance" "bbgo" {
#   identifier          = "${var.project_name}-instance"
#   cluster_identifier  = aws_rds_cluster.bbgo.id
#   instance_class      = "db.t3.micro"
#   engine              = aws_rds_cluster.bbgo.engine
#   engine_version      = aws_rds_cluster.bbgo.engine_version
#   publicly_accessible = false
#
#   tags = {
#     Name = "${var.project_name}-aurora-instance"
#   }
# }

# Redis will run locally on EC2 - no ElastiCache cluster needed

# IAM Role for EC2
resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ec2-role"
  }
}

# IAM Policy for CloudWatch Logs
resource "aws_iam_role_policy" "ec2_cloudwatch" {
  name = "${var.project_name}-ec2-cloudwatch-policy"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Key Pair
resource "aws_key_pair" "bbgo" {
  key_name   = "${var.project_name}-key"
  public_key = var.ssh_public_key

  tags = {
    Name = "${var.project_name}-key"
  }
}

# EC2 Instance
resource "aws_instance" "bbgo" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = aws_key_pair.bbgo.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  user_data = templatefile("${path.module}/user-data.sh", {
    # RDS will be created manually - these are just placeholders
    db_endpoint = "MANUALLY_CREATED_RDS_ENDPOINT"
    db_name     = var.db_name
    db_username = var.db_username
  })

  tags = {
    Name = "${var.project_name}-ec2"
  }

  # No RDS dependency - will be created manually
  # depends_on = [
  #   aws_rds_cluster_instance.bbgo
  # ]
}

# Elastic IP
resource "aws_eip" "bbgo" {
  domain   = "vpc"
  instance = aws_instance.bbgo.id

  tags = {
    Name = "${var.project_name}-eip"
  }

  depends_on = [aws_internet_gateway.bbgo]
}
