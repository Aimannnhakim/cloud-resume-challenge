# main.tf

# 1. Configure the AWS Provider
provider "aws" {
  region = "us-east-1" # Standard region for CloudFront certificates
}

# 2. Create the S3 Bucket (Your hard drive in the cloud)
resource "aws_s3_bucket" "resume_bucket" {
  # Bucket names must be globally unique! 
  # Change this to something like: "yourname-resume-2025-challenge"
  bucket = "replace-this-with-unique-name-12345" 
}

# 3. Block Public Access (Security Best Practice)
# We only want CloudFront to access the bucket, not the whole internet directly.
resource "aws_s3_bucket_public_access_block" "resume_bucket_block" {
  bucket = aws_s3_bucket.resume_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 4. Create Origin Access Control (OAC)
# This acts as a "key card" that lets CloudFront open your locked S3 bucket.
resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "resume-oac"
  description                       = "CloudFront Access to S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# 5. Create the CloudFront Distribution (The CDN)
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.resume_bucket.bucket_regional_domain_name
    origin_id                = "S3-Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html" # The file to load when someone visits your site

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-Origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https" # Force HTTPS
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# 6. S3 Bucket Policy
# This allows the "Key Card" (OAC) we created earlier to actually work.
resource "aws_s3_bucket_policy" "allow_cloudfront" {
  bucket = aws_s3_bucket.resume_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.resume_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })
}

# 7. Output the URL
# This will print your website link after Terraform finishes.
output "website_url" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}