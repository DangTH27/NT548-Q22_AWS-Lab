output "instance_ids" {
  description = "IDs của tất cả EC2 instances"
  value       = aws_instance.web[*].id
}

output "instance_private_ips" {
  description = "Private IP của các EC2 instances"
  value       = aws_instance.web[*].private_ip
}
