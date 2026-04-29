output "vpc_id" {
  description = "ID của VPC đã tạo"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs của các Public Subnets (nơi ALB & NAT GW đặt)"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs của các Private Subnets (nơi EC2 đặt)"
  value       = module.vpc.private_subnet_ids
}

output "alb_dns_name" {
  description = "DNS name của Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "vote_url" {
  description = "URL truy cập trang Vote"
  value       = "http://${module.alb.alb_dns_name}"
}

output "result_url" {
  description = "URL truy cập trang Result"
  value       = "http://${module.alb.alb_dns_name}:8081"
}

output "web_server_instance_ids" {
  description = "IDs của các EC2 Web Server instances"
  value       = module.compute.instance_ids
}

output "web_server_private_ips" {
  description = "Private IP của các EC2 instances"
  value       = module.compute.instance_private_ips
}

output "bastion_public_ip" {
  description = "Public IP của Bastion Host"
  value       = module.bastion.bastion_public_ip
}

output "bastion_ssh_command" {
  description = "Lệnh SSH vào Bastion Host"
  value       = "ssh -i bastion-key.pem ec2-user@${module.bastion.bastion_public_ip}"
}

output "bastion_private_key" {
  description = "Private key SSH (chạy: terraform output -raw bastion_private_key > bastion-key.pem)"
  value       = module.bastion.private_key_pem
  sensitive   = true
}
