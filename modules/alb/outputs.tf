output "alb_dns_name" {
  description = "DNS name của ALB - dùng để truy cập ứng dụng"
  value       = aws_lb.main.dns_name
}

output "alb_security_group_id" {
  description = "ID của ALB Security Group - compute module cần để tạo EC2 SG rule"
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "ARN của Vote Target Group - compute module cần để đăng ký EC2"
  value       = aws_lb_target_group.vote.arn
}

output "result_target_group_arn" {
  description = "ARN của Result Target Group"
  value       = aws_lb_target_group.result.arn
}
