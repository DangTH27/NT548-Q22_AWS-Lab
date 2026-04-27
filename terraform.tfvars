# ==============================================================
# Giá trị biến cho môi trường Dev/Lab
# File này CÓ THỂ commit lên Git vì không chứa thông tin nhạy cảm
# ==============================================================

aws_region   = "ap-southeast-1"   # Singapore - gần Việt Nam nhất
project_name = "3tier-lab"
environment  = "dev"

# Networking
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
availability_zones   = ["ap-southeast-1a", "ap-southeast-1b"]

# Compute - dùng t2.micro để nằm trong Free Tier
instance_type  = "t2.micro"
instance_count = 2
