resource "aws_kinesis_firehose_delivery_stream" "mempool_firehose" {
  name        = "${var.project_name}-firehose"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.mempool_data_bucket.arn

    prefix              = "mempool-data/"
    error_output_prefix = "mempool-data-errors/"
    buffering_size      = 128
    buffering_interval  = 60
  }

  tags = {
    Environment = var.environment
  }

  depends_on = [aws_iam_role_policy.firehose_policy]
}
