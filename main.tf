# ==============================================================
# Root Module - Điều phối toàn bộ hạ tầng 3-tier
#
# Kiến trúc:
#   [Internet] → ALB (Public Subnet) → EC2 (Private Subnet)
#
# Thứ tự phụ thuộc:
#   vpc → alb (cần vpc_id, public_subnet_ids)
#   vpc → compute (cần vpc_id, private_subnet_ids)
#   alb → compute (cần alb_security_group_id, target_group_arn)
# ==============================================================

# ------ Layer 1: Networking ------
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

# ------ Layer 2: Load Balancer (Public Tier) ------
module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}

# ------ Layer 2.5: Bastion Host (SSH Jump Box) ------
module "bastion" {
  source = "./modules/compute/bastion"

  project_name     = var.project_name
  environment      = var.environment
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_ids[0]
}

# ------ Layer 3: Web Servers (Private Tier) ------
module "compute" {
  source = "./modules/compute"

  project_name               = var.project_name
  environment                = var.environment
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  instance_type              = var.instance_type
  instance_count             = var.instance_count
  alb_security_group_id      = module.alb.alb_security_group_id
  alb_target_group_arn       = module.alb.target_group_arn
  result_target_group_arn    = module.alb.result_target_group_arn
  bastion_security_group_id  = module.bastion.bastion_security_group_id
  key_name                   = module.bastion.key_pair_name
}
