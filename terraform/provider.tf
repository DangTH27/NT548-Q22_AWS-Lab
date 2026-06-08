# ==============================================================
# Provider Configuration
# ==============================================================
# QUAN TRỌNG: Không bao giờ khai báo Access Key/Secret Key ở đây!
#
# Cách xác thực (chọn 1 trong 2):
#
# [Cách 1 - Khuyến nghị] Dùng AWS CLI:
#   $ aws configure
#   → Nhập Access Key ID, Secret Access Key, Region
#   → Credentials được lưu tại ~/.aws/credentials
#
# [Cách 2] Biến môi trường:
#   Linux/macOS:
#     export AWS_ACCESS_KEY_ID="your_access_key"
#     export AWS_SECRET_ACCESS_KEY="your_secret_key"
#     export AWS_DEFAULT_REGION="ap-southeast-1"
#   Windows (PowerShell):
#     $env:AWS_ACCESS_KEY_ID="your_access_key"
#     $env:AWS_SECRET_ACCESS_KEY="your_secret_key"
#     $env:AWS_DEFAULT_REGION="ap-southeast-1"
# ==============================================================

terraform {
  required_version = ">= 1.3.0"

  backend "s3" {
    bucket         = "dangth-terraform-state-s3"
    key            = "global/s3/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "dangth27-terraform-state-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Gắn default tags cho TẤT CẢ resources (best practice)
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
