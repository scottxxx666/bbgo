output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.bbgo.id
}

output "public_subnet_id" {
  description = "Public Subnet ID"
  value       = aws_subnet.public.id
}

output "private_subnet_ids" {
  description = "Private Subnet IDs"
  value       = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

output "ec2_instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.bbgo.id
}

output "ec2_public_ip" {
  description = "EC2 Public IP (Elastic IP)"
  value       = aws_eip.bbgo.public_ip
}

output "ec2_ssh_command" {
  description = "SSH command to connect to EC2 instance"
  value       = "ssh -i ~/.ssh/bbgo-key.pem ec2-user@${aws_eip.bbgo.public_ip}"
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.bbgo.address
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = aws_db_instance.bbgo.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.bbgo.db_name
}

output "security_group_ec2_id" {
  description = "EC2 Security Group ID"
  value       = aws_security_group.ec2.id
}

output "security_group_rds_id" {
  description = "RDS Security Group ID"
  value       = aws_security_group.rds.id
}

output "deployment_summary" {
  description = "Deployment summary"
  sensitive   = true
  value = <<-EOT
    ========================================
    BBGO XMaker Deployment Summary
    ========================================

    EC2 Instance:
      - Instance ID: ${aws_instance.bbgo.id}
      - Public IP: ${aws_eip.bbgo.public_ip}
      - SSH Command: ssh -i ~/.ssh/bbgo-key.pem ec2-user@${aws_eip.bbgo.public_ip}

    RDS PostgreSQL:
      - Endpoint: ${aws_db_instance.bbgo.address}
      - Port: ${aws_db_instance.bbgo.port}
      - Database: ${aws_db_instance.bbgo.db_name}
      - Username: ${var.db_username}

    Persistence:
      - Type: JSON files
      - Location: ~/bbgo-prod/var/data/

    Next Steps:
      1. Wait 5-10 minutes for EC2 user-data script to complete
      2. SSH to EC2: ssh -i ~/.ssh/bbgo-key.pem ec2-user@${aws_eip.bbgo.public_ip}
      3. Create .env.local from template and add your API keys
      4. Run database migrations: bbgo-migrate
      5. Run BBGO: bbgo-run

    ========================================
  EOT
}
