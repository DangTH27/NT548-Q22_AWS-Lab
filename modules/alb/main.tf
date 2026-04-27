# ==============================================================
# ALB Module - Application Load Balancer (Public Tier)
#
# Tài nguyên tạo ra:
#   - Security Group cho ALB (mở 80, 8081 từ Internet)
#   - Application Load Balancer (internet-facing, Public Subnets)
#   - 2 Target Groups: Vote (port 8080) và Result (port 8081)
#   - 2 Listeners: Port 80 → Vote, Port 8081 → Result
# ==============================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ----------------------------------------------------------------
# Security Group: ALB
# ----------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Allow HTTP traffic from internet to ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "Vote app (HTTP)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Result app"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound (ALB to EC2)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

# ----------------------------------------------------------------
# Application Load Balancer
# ----------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

# ----------------------------------------------------------------
# Target Group: Vote App (port 8080)
# ----------------------------------------------------------------
resource "aws_lb_target_group" "vote" {
  name     = "${local.name_prefix}-vote-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = "/"
    port                = "8080"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${local.name_prefix}-vote-tg"
  }
}

# ----------------------------------------------------------------
# Target Group: Result App (port 8081)
# ----------------------------------------------------------------
resource "aws_lb_target_group" "result" {
  name     = "${local.name_prefix}-result-tg"
  port     = 8081
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = "/"
    port                = "8081"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  tags = {
    Name = "${local.name_prefix}-result-tg"
  }
}

# ----------------------------------------------------------------
# Listener: Port 80 → Vote App
# ----------------------------------------------------------------
resource "aws_lb_listener" "vote" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vote.arn
  }
}

# ----------------------------------------------------------------
# Listener: Port 8081 → Result App
# ----------------------------------------------------------------
resource "aws_lb_listener" "result" {
  load_balancer_arn = aws_lb.main.arn
  port              = 8081
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.result.arn
  }
}
