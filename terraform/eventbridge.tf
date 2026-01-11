resource "aws_cloudwatch_event_rule" "mempool_eventbridge" {
  name        = "${var.project_name}-event-rule"
  description = "EventBridge rule for Mempool data events"

  event_pattern = jsonencode({
    source      = ["mempool.space"]
    detail-type = ["transaction"]
  })

  tags = {
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "mempool_lambda_target" {
  rule      = aws_cloudwatch_event_rule.mempool_eventbridge.name
  target_id = "${var.project_name}-lambda-target"
  arn       = aws_lambda_function.mempool_lambda.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mempool_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.mempool_eventbridge.arn
}
