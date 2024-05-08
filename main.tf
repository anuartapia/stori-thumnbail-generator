terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.36.1"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
  required_version = "~> 1.0"
}

provider "aws" {
  region = var.aws_region
}

# original-image bucket
resource "aws_s3_bucket" "original_image_bucket" {
  bucket = "stori-original-image-bucket"
}

# thumbnail-image bucket
resource "aws_s3_bucket" "thumbnail_image_bucket" {
  bucket = "stori-thumbnail-image-bucket"
}

# helper module to package Lambda Python code
data "archive_file" "thumbnail_lambda_source_archive" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/app.zip"
}

# Lambda configuration with public 'pillow' library base layer
resource "aws_lambda_function" "thumbnail_lambda" {
  function_name    = "thumbnail_generation_lambda"
  filename         = "${path.module}/app.zip"
  runtime          = "python3.9"
  handler          = "app.lambda_handler"
  memory_size      = var.thumbnail_lambda_memory
  source_code_hash = data.archive_file.thumbnail_lambda_source_archive.output_base64sha256
  role             = aws_iam_role.thumbnail_lambda_role.arn
  layers           = [
    "arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p39-pillow:1"
  ]
  environment {
    variables = {
      thumbnail_bucket = aws_s3_bucket.thumbnail_image_bucket.bucket
      max_width = var.max_thumbnail_width
      max_height = var.max_thumbnail_height
    }
  }
}

# Logs for Lambda
resource "aws_cloudwatch_log_group" "thumbnail_cloudwatch" {
  name = "/aws/lambda/${aws_lambda_function.thumbnail_lambda.function_name}"
  retention_in_days = 30
}

# Bucket Notification
resource "aws_s3_bucket_notification" "thumbnail_notification" {
  bucket = aws_s3_bucket.original_image_bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.thumbnail_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [
    aws_lambda_permission.thumbnail_allow_bucket
  ]
}

# policy to configure access to read objects from original-image bucket, and to write to thumbnail-image bucket. As well to trigger Lambda
resource "aws_iam_policy" "thumbnail_s3_policy" {
  name   = "thumbnail_s3_policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "s3:GetObject",
        "Resource" : "arn:aws:s3:::stori-original-image-bucket/*"
      }, {
        "Effect" : "Allow",
        "Action" : "s3:PutObject",
        "Resource" : "arn:aws:s3:::stori-thumbnail-image-bucket/*"
      }
    ]
  })
}

# role to be bound to the policy
resource "aws_iam_role" "thumbnail_lambda_role" {
  name               = "thumbnail_lambda_role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

# attach the role to the policy
resource "aws_iam_policy_attachment" "thumbnail_role_s3_policy_attachment" {
  name       = "thumbnail_role_s3_policy_attachment"
  roles      = [aws_iam_role.thumbnail_lambda_role.name]
  policy_arn = aws_iam_policy.thumbnail_s3_policy.arn
}

resource "aws_iam_policy_attachment" "thumbnail_role_lambda_policy_attachment" {
  name       = "thumbnail_role_lambda_policy_attachment"
  roles      = [aws_iam_role.thumbnail_lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda invoke permission from original-image bucket
resource "aws_lambda_permission" "thumbnail_allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.thumbnail_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.original_image_bucket.arn
}