variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "bbgo-xmaker"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "production"
}

variable "my_ip" {
  description = "Your public IP address for SSH access (format: x.x.x.x/32)"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}/32$", var.my_ip))
    error_message = "The my_ip must be a valid IPv4 CIDR block with /32 suffix (e.g., 1.2.3.4/32)."
  }
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 access"
  type        = string
  sensitive   = true
}

# Database Configuration
variable "db_name" {
  description = "Aurora PostgreSQL database name"
  type        = string
  default     = "bbgo"
}

variable "db_username" {
  description = "Aurora PostgreSQL master username"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "db_password" {
  description = "Aurora PostgreSQL master password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "Database password must be at least 8 characters long."
  }
}

# Removed: skip_final_snapshot variable
# Database will always be destroyed without final snapshot

# Note: Exchange API keys and strategy configuration are managed manually
# in .env.local and config/xmaker.yaml on the EC2 instance.
# This keeps sensitive credentials out of Terraform state.
