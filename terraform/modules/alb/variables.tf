variable "project_name" {
  description = "Tên project"
  type        = string
}

variable "environment" {
  description = "Môi trường (dev/staging/prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID của VPC (nhận từ vpc module)"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs của Public Subnets để đặt ALB (cần ít nhất 2 AZ)"
  type        = list(string)
}
