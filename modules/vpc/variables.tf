variable "project_name" {
  description = "Tên project"
  type        = string
}

variable "environment" {
  description = "Môi trường (dev/staging/prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block của VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Danh sách CIDR của Public Subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Danh sách CIDR của Private Subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "Danh sách Availability Zones"
  type        = list(string)
}
