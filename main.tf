variable "AWS_ACCESS_KEY_ID" {
  type = string
}

variable "AWS_SECRET_ACCESS_KEY" {
  type = string
}

variable "AWS_SESSION_TOKEN" {
  type = string
}

locals {
    emails =["yourmail@example.com"]
}

provider "aws" {
  region = "us-east-1"
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
  token = var.AWS_SESSION_TOKEN
}
resource "cloudtrail" "main_cloudtrail" {
  name="main_cloudtrail"
}
resource "aws_cloudwatch_event_rule" "sec_event_rule" {
  name = "sec_event_rule"
  description = "Capture each IAM Account creation"

  event_pattern = jsonencode({
    source = ["aws_iam"]
    detail = {
        "eventSource"= ["iam.amazonaws.com"]
        "eventName" = ["CreateUser"]
    }
    detail-type = [
        "AWS API Call via CloudTrail"
    ]
  })
}

data "aws_iam_policy_document" "assume_role"{
    statement {
      effect = "Allow"
      principals {
        type = "Service"
        identifiers = ["lambda.amazonaws.com"]
      }
      actions = ["sts:AssumeRole"]
    }
}
data "aws_iam_policy_document" "sns_policy_json"{
    statement {
      effect = "Allow"
      actions = ["sns:Publish"]
      resources = ["*"]
    }

}
resource "aws_iam_policy" "sns_policy" {
  name = "test-policy"
  description = "A test policy"
  policy = data.aws_iam_policy_document.sns_policy_json.json
}
resource "aws_iam_role" "iam_for_lambda" {
  name = iam_for_lambda
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}
resource "aws_iam_role_policy_attachment" "test-attach" {
  role = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.sns_policy.arn
}
resource "aws_iam_role_policy_attachment" "test-attach" {
  role = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
data "archive_file" "lambda_zip" {
  type = "zip"
  source_dir = "${path.module}/src/sec_lambda"
  output_path = "${path.module}/myzip/python.zip"
}
resource "aws_lambda_function" "sec_lambda" {
  filename = data.archive_file.lambda_zip.output_path
  function_name = "SendNotificationLambda"
  role = aws_iam_role.iam_for_lambda.arn
  handler = "index.handler"
  runtime = "python3.9"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  environment {
    variables= {
        TOPIC_ARN = aws_sns_topic.notify_topic.arn
    }
  }
}
resource "aws_sns_topic" "notify_topic" {
  name = "notify_topic"
}

resource "aws_sns_topic_subscription" "example_email_subscription" {
  count = length(local.emails)
  topic_arn = aws_sns_topic.notify_topic.arn
  protocol  = "email"
  endpoint  = local.emails[count.index]
}

resource "aws_lambda_permission" "allow_cloudwatch_to_invoke" {
  statement_id  = "AllowCloudwatchToInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sec_lambda.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sec_event_rule.arn
}
resource "aws_cloudwatch_event_target" "example_event_target" {
  rule      = aws_cloudwatch_event_rule.sec_event_rule.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.sec_lambda.arn
}