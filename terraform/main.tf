locals {
  function_name = "next-js-website"
}

terraform {
  required_version = "~> 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.25.0"
    }
  }
}
provider "aws" {
  region  = "us-east-1"
  profile = "innovate"
}


# LAMBDA

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "archive_file" "function_package" {
  type        = "zip"
  source_dir  = "../.next/standalone"
  output_path = "deployment.zip"
}

resource "aws_lambda_function" "this" {
  filename         = data.archive_file.function_package.output_path
  function_name    = local.function_name
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "run.sh"
  runtime          = "nodejs18.x"
  architectures    = ["x86_64"]
  layers           = ["arn:aws:lambda:us-east-1:753240598075:layer:LambdaAdapterLayerX86:17"]
  depends_on       = [aws_cloudwatch_log_group.lambda_log_group]
  memory_size      = 3008
  timeout          = 30
  source_code_hash = data.archive_file.function_package.output_base64sha256
  environment {
    variables = {
      "AWS_LAMBDA_EXEC_WRAPPER" = "/opt/bootstrap",
      "RUST_LOG"                = "info",
      "PORT"                    = "3000",
      "NODE_ENV"                = "production"
      "AWS_LWA_INVOKE_MODE"     = "response_stream"
    }
  }
}
resource "aws_lambda_function_url" "this" {
  function_name      = local.function_name
  authorization_type = "NONE"
  invoke_mode        = "RESPONSE_STREAM"
}

# CLOUDWATCH

data "aws_iam_policy" "lambda_basic_execution_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_flow_log_cloudwatch" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = data.aws_iam_policy.lambda_basic_execution_policy.arn
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}


# CLOUD FRONT

resource "aws_cloudfront_distribution" "cf_distribution" {
  origin {
    # This is required because "domain_name" needs to be in a specific format
    domain_name = replace(replace(aws_lambda_function_url.this.function_url, "https://", ""), "/", "")
    origin_id   = local.function_name

    custom_origin_config {
      https_port             = 443
      http_port              = 80
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.function_name
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "origin request policy test"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "test"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "lambda_url" {
  value = aws_lambda_function_url.this.function_url
}
output "cf_distribution_domain_url" {
  value = "https://${aws_cloudfront_distribution.cf_distribution.domain_name}"
}
