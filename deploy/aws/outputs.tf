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

# Aurora outputs commented out - RDS will be created manually
# output "aurora_cluster_endpoint" {
#   description = "Aurora PostgreSQL cluster endpoint"
#   value       = aws_rds_cluster.bbgo.endpoint
# }
#
# output "aurora_reader_endpoint" {
#   description = "Aurora PostgreSQL reader endpoint"
#   value       = aws_rds_cluster.bbgo.reader_endpoint
# }
#
# output "aurora_cluster_id" {
#   description = "Aurora Cluster ID"
#   value       = aws_rds_cluster.bbgo.cluster_identifier
# }
#
# output "aurora_database_name" {
#   description = "Aurora database name"
#   value       = aws_rds_cluster.bbgo.database_name
# }

output "security_group_ec2_id" {
  description = "EC2 Security Group ID"
  value       = aws_security_group.ec2.id
}

# RDS security group commented out - will be created manually
# output "security_group_rds_id" {
#   description = "RDS Security Group ID"
#   value       = aws_security_group.rds.id
# }

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

    Database:
      - Create RDS manually through AWS Console
      - Recommended: PostgreSQL or Aurora PostgreSQL
      - Use VPC: ${aws_vpc.bbgo.id}
      - Use Subnets: Private subnets (see outputs above)
      - Security: Allow access from EC2 security group

    Persistence:
      - Type: JSON files
      - Location: ~/bbgo-prod/var/data/

    Next Steps:
      1. Create RDS database manually in AWS Console (optional)
      2. Wait 5-10 minutes for EC2 user-data script to complete
      3. SSH to EC2: ssh -i ~/.ssh/bbgo-key.pem ec2-user@${aws_eip.bbgo.public_ip}
      4. Edit .env.local with your RDS endpoint and API keys
      5. Run: bbgo-migrate (if using database)
      6. Run: bbgo-run

    ========================================
  EOT
}
