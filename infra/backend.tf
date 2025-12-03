# infra/backend.tf

# --- 1. The Database (DynamoDB) ---
resource "aws_dynamodb_table" "counter_table" {
  name           = "cloud-resume-challenge-visitor-counter"
  billing_mode   = "PAY_PER_REQUEST" # Free tier friendly
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S" # S = String
  }
}

# --- 2. The Archive (Zip the Python code) ---
# Terraform will automatically zip your Python file before uploading
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../backend/func.py" # Path to your Python file
  output_path = "${path.module}/packed_lambda.zip"
}

# --- 3. The IAM Role (Permissions) ---
# This allows Lambda to assume an identity
resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda_counter"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Give the Lambda permission to write to CloudWatch Logs (for debugging)
# AND permission to Read/Write to our specific DynamoDB table
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_dynamo_policy"
  description = "IAM policy for logging and dynamo"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*",
        Effect   = "Allow"
      },
      {
        Action = [
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:PutItem"
        ],
        Resource = aws_dynamodb_table.counter_table.arn,
        Effect   = "Allow"
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# --- 4. The Compute (Lambda Function) ---
resource "aws_lambda_function" "visitor_counter" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "visitor_counter_func"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "func.lambda_handler" # filename.function_name
  runtime       = "python3.9"
  
  # Updates the Lambda when code changes
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# --- 5. The Interface (Function URL) ---
# For simplicity, we will use a "Lambda Function URL" instead of full API Gateway
# It gives us a public HTTPS endpoint for the function.
resource "aws_lambda_function_url" "counter_url" {
  function_name      = aws_lambda_function.visitor_counter.function_name
  authorization_type = "NONE" # Publicly accessible

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }
}

# --- 6. Output the API Endpoint ---
output "api_endpoint" {
  value = aws_lambda_function_url.counter_url.function_url
}
