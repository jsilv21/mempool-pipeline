output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.mempool_ec2.id
}

output "ec2_public_ip" {
  description = "EC2 public IP address"
  value       = aws_instance.mempool_ec2.public_ip
}

output "s3_bucket_name" {
  description = "S3 bucket name for Mempool data"
  value       = aws_s3_bucket.mempool_data_bucket.bucket
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.mempool_data_bucket.arn
}

output "firehose_stream_delivery_name" {
  description = "Kinesis Firehose delivery stream name (mempool stream)"
  value       = aws_kinesis_firehose_delivery_stream.mempool_firehose_stream.name
}

output "firehose_stream_delivery_arn" {
  description = "Kinesis Firehose delivery stream ARN (mempool stream)"
  value       = aws_kinesis_firehose_delivery_stream.mempool_firehose_stream.arn
}

output "firehose_conversions_delivery_name" {
  description = "Kinesis Firehose delivery stream name (conversions)"
  value       = aws_kinesis_firehose_delivery_stream.mempool_firehose_conversions.name
}

output "firehose_conversions_delivery_arn" {
  description = "Kinesis Firehose delivery stream ARN (conversions)"
  value       = aws_kinesis_firehose_delivery_stream.mempool_firehose_conversions.arn
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.mempool_lambda.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.mempool_lambda.arn
}

output "eventbridge_rule_name" {
  description = "EventBridge rule name"
  value       = aws_cloudwatch_event_rule.mempool_eventbridge.name
}
