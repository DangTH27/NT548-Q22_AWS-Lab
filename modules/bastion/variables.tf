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

variable "public_subnet_id" {
  description = "ID của Public Subnet để đặt Bastion"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "Danh sách CIDR được phép SSH vào Bastion (mặc định: mọi nơi)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
