variable "aws_region" {
  description = "AWS Region để deploy tài nguyên"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Tên project, dùng làm prefix cho tên tài nguyên"
  type        = string
  default     = "3tier-lab"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name chỉ được chứa chữ thường, số và dấu gạch ngang."
  }
}

variable "environment" {
  description = "Môi trường triển khai (dev / staging / prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment phải là một trong: dev, staging, prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block cho toàn bộ VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Danh sách CIDR cho Public Subnets (1 subnet/AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Danh sách CIDR cho Private Subnets (1 subnet/AZ)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "availability_zones" {
  description = "Danh sách AZ tương ứng với từng subnet (phải khớp số lượng với subnet CIDRs)"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "instance_type" {
  description = "Loại EC2 instance cho Web Server"
  type        = string
  default     = "t2.micro" 
}

variable "instance_count" {
  description = "Số lượng EC2 Web Server"
  type        = number
  default     = 2

  validation {
    condition     = var.instance_count >= 1
    error_message = "Cần ít nhất 1 instance."
  }
}
