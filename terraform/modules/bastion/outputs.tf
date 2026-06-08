output "bastion_public_ip" {
  description = "Public IP của Bastion Host - dùng để SSH vào"
  value       = aws_instance.bastion.public_ip
}

output "bastion_security_group_id" {
  description = "Security Group ID của Bastion - compute module cần để mở SSH"
  value       = aws_security_group.bastion.id
}

output "bastion_instance_id" {
  description = "Instance ID của Bastion Host"
  value       = aws_instance.bastion.id
}

output "private_key_pem" {
  description = "Private key để SSH (lưu vào file .pem)"
  value       = tls_private_key.bastion.private_key_pem
  sensitive   = true
}

output "key_pair_name" {
  description = "Tên Key Pair đã tạo trên AWS"
  value       = aws_key_pair.bastion.key_name
}
