resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.environment}-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-public-b"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.environment}-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "${var.environment}-private-b"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.environment}-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "images" {
  bucket = "image-processor-${var.environment}-${random_id.suffix.hex}"

  tags = {
    Name        = "image-processor-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "images" {
  bucket = aws_s3_bucket.images.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket = aws_s3_bucket.images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_sqs_queue" "dlq" {
  name                      = "image-dlq-${var.environment}"
  message_retention_seconds = 1209600 # 14 days

  tags = {
    Name = "image-dlq-${var.environment}"
  }
}

resource "aws_sqs_queue" "main" {
  name                       = "image-queue-${var.environment}"
  visibility_timeout_seconds = 360 # 6 min (6x lambda timeout)
  message_retention_seconds  = 86400 # 1 day

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name = "image-queue-${var.environment}"
  }
}

resource "aws_sqs_queue_policy" "allow_s3" {
  queue_url = aws_sqs_queue.main.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "s3.amazonaws.com" },
      Action    = "sqs:SendMessage",
      Resource  = aws_sqs_queue.main.arn,
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_s3_bucket.images.arn
        }
      }
    }]
  })
}

resource "aws_iam_role" "upload_role" {
  name = "upload-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Name = "upload-role-${var.environment}"
  }
}

resource "aws_iam_role_policy" "upload_s3_policy" {
  name = "upload-s3-policy"
  role = aws_iam_role.upload_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ],
        Resource = "${aws_s3_bucket.images.arn}/uploads/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "upload_logs" {
  role       = aws_iam_role.upload_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role" "crop_role" {
  name = "crop-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Name = "crop-role-${var.environment}"
  }
}

resource "aws_iam_role_policy" "crop_s3_policy" {
  name = "crop-s3-policy"
  role = aws_iam_role.crop_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject"
        ],
        Resource = "${aws_s3_bucket.images.arn}/uploads/*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ],
        Resource = "${aws_s3_bucket.images.arn}/processed/*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "crop_sqs_policy" {
  name = "crop-sqs-policy"
  role = aws_iam_role.crop_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ],
        Resource = aws_sqs_queue.main.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "crop_logs" {
  role       = aws_iam_role.crop_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "upload_logs" {
  name              = "/aws/lambda/upload-${var.environment}"
  retention_in_days = 14

  tags = {
    Name = "upload-logs-${var.environment}"
  }
}

resource "aws_cloudwatch_log_group" "crop_logs" {
  name              = "/aws/lambda/crop-${var.environment}"
  retention_in_days = 14

  tags = {
    Name = "crop-logs-${var.environment}"
  }
}

resource "aws_lambda_function" "upload" {
  function_name = "upload-${var.environment}"
  role          = aws_iam_role.upload_role.arn
  runtime       = "nodejs20.x"
  handler       = "index.handler"
  timeout       = 30
  memory_size   = 256

  filename         = "../lambdas/upload/upload.zip"
  source_code_hash = filebase64sha256("../lambdas/upload/upload.zip")

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.images.bucket
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.upload_logs,
    aws_iam_role_policy.upload_s3_policy
  ]

  tags = {
    Name = "upload-${var.environment}"
  }
}

resource "aws_lambda_function" "crop" {
  function_name = "crop-${var.environment}"
  role          = aws_iam_role.crop_role.arn
  runtime       = "nodejs20.x"
  handler       = "index.handler"
  timeout       = 60
  memory_size   = 512

  filename         = "../lambdas/crop/crop.zip"
  source_code_hash = filebase64sha256("../lambdas/crop/crop.zip")

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.images.bucket
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.crop_logs,
    aws_iam_role_policy.crop_s3_policy,
    aws_iam_role_policy.crop_sqs_policy
  ]

  tags = {
    Name = "crop-${var.environment}"
  }
}

resource "aws_apigatewayv2_api" "main" {
  name          = "image-api-${var.environment}"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type"]
  }

  tags = {
    Name = "image-api-${var.environment}"
  }
}

resource "aws_apigatewayv2_integration" "upload" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.upload.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "upload" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.upload.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  tags = {
    Name = "default-stage-${var.environment}"
  }
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_s3_bucket_notification" "notify" {
  bucket = aws_s3_bucket.images.id

  queue {
    queue_arn     = aws_sqs_queue.main.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/"
  }

  depends_on = [aws_sqs_queue_policy.allow_s3]
}

resource "aws_lambda_event_source_mapping" "crop_trigger" {
  event_source_arn = aws_sqs_queue.main.arn
  function_name    = aws_lambda_function.crop.arn
  batch_size       = 5

  function_response_types = ["ReportBatchItemFailures"]
}