data "archive_file" "mempool_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src/lambda"
  output_path = "${path.module}/../build/mempool_lambda.zip"
}

resource "aws_lambda_function" "mempool_lambda" {
  function_name = "${var.project_name}-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.handler"
  runtime       = var.lambda_runtime

  filename         = data.archive_file.mempool_lambda_zip.output_path
  source_code_hash = data.archive_file.mempool_lambda_zip.output_base64sha256

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
