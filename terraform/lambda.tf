resource "aws_lambda_function" "mempool_lambda" {
  function_name = "${var.project_name}-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = var.lambda_runtime

  s3_bucket = aws_s3_bucket.mempool_data_bucket.bucket
  s3_key    = "lambda.zip"

  environment {
    variables = {
      ENVIRONMENT = var.environment
      PROJECT     = var.project_name
    }
  }

  tags = {
    Environment = var.environment
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution]
}
