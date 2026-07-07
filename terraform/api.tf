# ============================================================================
# API Gateway & Lambda Backend for EC2 Start/Stop
# ============================================================================

# ── 1. IAM Role for Lambda ────────────────────────────────────────────────
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_ec2_role" {
  name               = "DashboardLambdaEC2Role-${data.aws_caller_identity.current.account_id}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_ec2_policy" {
  statement {
    sid    = "ReadOnlyEC2AndSSM"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "StartStopEC2"
    effect = "Allow"
    actions = [
      "ec2:StartInstances",
      "ec2:StopInstances"
    ]
    resources = [
      "arn:aws:ec2:${local.region}:${data.aws_caller_identity.current.account_id}:instance/*"
    ]
  }

  statement {
    sid    = "SendCommand"
    effect = "Allow"
    actions = [
      "ssm:SendCommand"
    ]
    resources = [
      "arn:aws:ec2:${local.region}:${data.aws_caller_identity.current.account_id}:instance/*",
      "arn:aws:ssm:${local.region}::document/AWS-RunShellScript"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "lambda_ec2_policy" {
  name        = "DashboardLambdaEC2Policy-${data.aws_caller_identity.current.account_id}"
  description = "Permissions for Lambda to start/stop EC2 instances"
  policy      = data.aws_iam_policy_document.lambda_ec2_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_ec2_attach" {
  role       = aws_iam_role.lambda_ec2_role.name
  policy_arn = aws_iam_policy.lambda_ec2_policy.arn
}

# ── 2. Lambda Function ────────────────────────────────────────────────────
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/ec2_handler.py"
  output_path = "${path.module}/lambda/ec2_handler.zip"
}

resource "aws_lambda_function" "ec2_handler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "DashboardEC2Manager-${data.aws_caller_identity.current.account_id}"
  role             = aws_iam_role.lambda_ec2_role.arn
  handler          = "ec2_handler.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = 15
}

# ── 3. API Gateway (HTTP API) ─────────────────────────────────────────────
resource "aws_apigatewayv2_api" "dashboard_api" {
  name          = "DashboardEC2API-${data.aws_caller_identity.current.account_id}"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"] # Ideally restrict to CloudFront domain later
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.dashboard_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.ec2_handler.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "ec2_route" {
  api_id    = aws_apigatewayv2_api.dashboard_api.id
  route_key = "POST /ec2"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.dashboard_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.dashboard_api.execution_arn}/*/*"
}
