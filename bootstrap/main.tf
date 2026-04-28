# ==============================================================
# Remote Backend Resources
# Tạo S3 Bucket và DynamoDB Table để lưu Terraform State
# ==============================================================

# 1. S3 Bucket để lưu file terraform.tfstate
resource "aws_s3_bucket" "terraform_state" {
  bucket        = "dangth-terraform-state-s3" # Tên này phải là duy nhất toàn cầu
  force_destroy = true # Cho phép xóa bucket kể cả khi có file (chỉ dùng cho Lab)

  tags = {
    Name = "Terraform State Bucket"
  }
}

# Bật Versioning để lưu nhiều phiên bản của file state
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Mã hóa file state trên S3
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 2. DynamoDB Table để làm khóa (State Locking)
# Đảm bảo không có 2 luồng GitHub Actions cùng apply 1 lúc gây lỗi
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "dangth27-terraform-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform State Lock Table"
  }
}
