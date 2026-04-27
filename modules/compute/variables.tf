variable "project_name" {
  description = "Tên project"
  type        = string
}

variable "environment" {
  description = "Môi trường (dev/staging/prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID của VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs của Private Subnets để đặt EC2"
  type        = list(string)
}

variable "instance_type" {
  description = "Loại EC2 instance"
  type        = string
}

variable "instance_count" {
  description = "Số lượng EC2 instances"
  type        = number
}

variable "alb_security_group_id" {
  description = "Security Group ID của ALB"
  type        = string
}

variable "alb_target_group_arn" {
  description = "ARN của Vote Target Group (ALB)"
  type        = string
}

variable "result_target_group_arn" {
  description = "ARN của Result Target Group (ALB)"
  type        = string
}

variable "bastion_security_group_id" {
  description = "Security Group ID của Bastion Host (để mở SSH)"
  type        = string
}

variable "key_name" {
  description = "Tên Key Pair để SSH vào EC2"
  type        = string
}
