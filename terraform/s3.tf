resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
}

resource "aws_s3_bucket" "mempool_data_bucket" {
  bucket = "${var.project_name}-data-bucket-${random_string.bucket_suffix.result}"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-data-bucket"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "mempool_data_bucket_versioning" {
  bucket = aws_s3_bucket.mempool_data_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}
