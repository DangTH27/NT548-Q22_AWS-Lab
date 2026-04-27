output "vpc_id" {
  description = "ID của VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs của Public Subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs của Private Subnets"
  value       = aws_subnet.private[*].id
}
