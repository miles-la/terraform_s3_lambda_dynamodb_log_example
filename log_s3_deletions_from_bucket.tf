#
# log_s3_deletions_from_bucket.tf by Miles Baker of Linux Academy on July 2, 2019
#
# Example Code Logging S3 Delete events to DynamoDB provided
# by LinuxAcademy for illustrative purposes only
#
#
provider "aws" {
  region = "us-east-1"
}
data "aws_caller_identity" "current" {}

#
# Variables
# These are usually stored in a separate file called variables.tf
# in the same folder.  For this demonstration the files have been
# combined.
#
variable "s3BucketName" {
  type    = string
  default = "s3-bucket-random-123456"
}

variable "dynamoDBTableName" {
  type    = string
  default = "s3-bucket-random-123456"
}

variable "environment" {
  type    = string
  default = "dev"
}
#
# S3 bucket
#
resource "aws_s3_bucket" "tf_s3_bucket" {
  bucket = "${var.s3BucketName}"
  acl = "private"
  versioning {
    enabled = true
  }

  tags = {
    Name = "${var.s3BucketName}"
    Environment = "${var.environment}"
  }

}
#
# DynamoDB
#
resource "aws_dynamodb_table" "tf_dynamo_db_table" {
  name           = "${var.dynamoDBTableName}"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "object_name"
  range_key      = "deleted_on"

  attribute {
    name = "object_name"
    type = "S"
  }

  attribute {
    name = "deleted_on"
    type = "S"
  }

  tags = {
    Name        = "${var.dynamoDBTableName}"
    Environment = "${var.environment}"
  }
}
#
# Lambda
#
data "archive_file" "tf_lambda_function_code_zip_file" {
  type        = "zip"
  source_file = "s3_object_deleted.py"
  output_path = "s3_object_deleted.zip"
}

resource "aws_iam_policy" "tf_iam_policy_for_lambda_s3_logging" {
  name = "lambda_s3_logging"
  path = "/"
  description = "IAM policy for logging S3 events from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    },
    {
      "Action": [
        "dynamodb:BatchWriteItem",
				"dynamodb:PutItem",
				"dynamodb:UpdateItem"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:${data.aws_caller_identity.current.account_id}:table/${var.dynamoDBTableName}",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role" "tf_role_for_lambda" {
  name = "tf_role_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_role_policy_attachment" {
  role       = "${aws_iam_role.tf_role_for_lambda.name}"
  policy_arn = "${aws_iam_policy.tf_iam_policy_for_lambda_s3_logging.arn}"
}

resource "aws_lambda_function" "tf_lambda_function" {
  filename         = "s3_object_deleted.zip"
  function_name    = "s3_object_deleted"
  role             = "${aws_iam_role.tf_role_for_lambda.arn}"
  handler          = "s3_object_deleted.lambda_handler"
  source_code_hash = "${data.archive_file.tf_lambda_function_code_zip_file.output_base64sha256}"
  runtime          = "python3.7"
  environment {
    variables = {
      DYNAMODB_TABLE = "${var.dynamoDBTableName}"
    }
  }
}

resource "aws_lambda_permission" "tf_lambda_permission_for_s3_trigger" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.tf_lambda_function.arn}"
  principal     = "s3.amazonaws.com"
  source_arn    = "${aws_s3_bucket.tf_s3_bucket.arn}"
}

resource "aws_s3_bucket_notification" "tf_bucket_notification_to_lambda" {
  bucket = "${aws_s3_bucket.tf_s3_bucket.id}"

  lambda_function {
    lambda_function_arn = "${aws_lambda_function.tf_lambda_function.arn}"
    events              = ["s3:ObjectRemoved:*"]
  }
}
