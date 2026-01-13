resource "aws_kinesis_firehose_delivery_stream" "mempool_firehose_stream" {
  name        = "${var.project_name}-firehose-stream"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.mempool_data_bucket.arn

    prefix              = "mempool-data/stream/"
    error_output_prefix = "mempool-data-errors/stream/"
    buffering_size      = 128
    buffering_interval  = 60
  }

  tags = {
    Environment = var.environment
  }

  depends_on = [aws_iam_role_policy.firehose_policy]
}

resource "aws_kinesis_firehose_delivery_stream" "mempool_firehose_conversions" {
  name        = "${var.project_name}-firehose-conversions"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.mempool_data_bucket.arn

    prefix              = "mempool-data/conversions/"
    error_output_prefix = "mempool-data-errors/conversions/"
    buffering_size      = 128
    buffering_interval  = 60
  }

  tags = {
    Environment = var.environment
  }

  depends_on = [aws_iam_role_policy.firehose_policy]
}
