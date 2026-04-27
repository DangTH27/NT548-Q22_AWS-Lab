# ==============================================================
# Compute Module - EC2 chạy Voting App qua Docker Compose
#
# Tài nguyên tạo ra:
#   - IAM Role + Instance Profile (SSM access, không cần SSH)
#   - Security Group (chỉ cho ALB truy cập port 8080, 8081)
#   - EC2 Instance chạy Docker Compose với 5 microservices
#   - Target Group Attachments cho Vote và Result
# ==============================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ----------------------------------------------------------------
# IAM Role cho EC2 (SSM - truy cập EC2 không cần SSH)
# ----------------------------------------------------------------
resource "aws_iam_role" "ec2_ssm" {
  name = "${local.name_prefix}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${local.name_prefix}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name
}

# ----------------------------------------------------------------
# AMI - Amazon Linux 2 (có sẵn SSM Agent)
# ----------------------------------------------------------------
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ----------------------------------------------------------------
# Security Group: EC2 - chỉ cho ALB kết nối vào
# ----------------------------------------------------------------
resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "Allow traffic from ALB to voting app containers"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Vote app from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  ingress {
    description     = "Result app from ALB"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  ingress {
    description     = "SSH from Bastion Host"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_security_group_id]
  }

  egress {
    description = "Allow all outbound (Docker pull, yum qua NAT GW)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-web-sg"
  }
}

# ----------------------------------------------------------------
# EC2 Instance
# ----------------------------------------------------------------
resource "aws_instance" "web" {
  count = var.instance_count

  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]

  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm.name
  associate_public_ip_address = false

  user_data = base64encode(file("${path.module}/templates/user_data.sh"))

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "${local.name_prefix}-voting-app-${count.index + 1}"
    Role = "voting-app"
  }
}

# ----------------------------------------------------------------
# Đăng ký EC2 vào ALB Target Groups
# ----------------------------------------------------------------
resource "aws_lb_target_group_attachment" "vote" {
  count            = var.instance_count
  target_group_arn = var.alb_target_group_arn
  target_id        = aws_instance.web[count.index].id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "result" {
  count            = var.instance_count
  target_group_arn = var.result_target_group_arn
  target_id        = aws_instance.web[count.index].id
  port             = 8081
}
