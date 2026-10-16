resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  default_root_object = "index.html"
  origin {
    domain_name = var.alb_dns_name
    origin_id   = local.alb_origin_id
    custom_header {
      name  = "X-Origin-Verify"
      value = var.cloudfront_header
    }
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  origin {
    domain_name              = var.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
    origin_id                = local.s3_origin_id
  }
  default_cache_behavior {
    allowed_methods          = ["GET", "HEAD"]
    cached_methods           = ["GET", "HEAD"]
    viewer_protocol_policy   = "redirect-to-https"
    cache_policy_id          = data.aws_cloudfront_cache_policy.optimized.id
    target_origin_id         = local.alb_origin_id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.main.id
  }
  ordered_cache_behavior {
    path_pattern             = "/alerts"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    viewer_protocol_policy   = "redirect-to-https"
    target_origin_id         = local.alb_origin_id
    cache_policy_id          = data.aws_cloudfront_cache_policy.main.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.main.id
  }

  ordered_cache_behavior {
    path_pattern             = "/alerts/*"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    viewer_protocol_policy   = "redirect-to-https"
    cache_policy_id          = data.aws_cloudfront_cache_policy.main.id
    target_origin_id         = local.alb_origin_id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.main.id
  }

  ordered_cache_behavior {
    path_pattern             = "/auth/*"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    viewer_protocol_policy   = "redirect-to-https"
    cache_policy_id          = data.aws_cloudfront_cache_policy.main.id
    target_origin_id         = local.alb_origin_id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.main.id
  }

  ordered_cache_behavior {
    path_pattern             = "/healthz"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    viewer_protocol_policy   = "redirect-to-https"
    target_origin_id         = local.alb_origin_id
    cache_policy_id          = data.aws_cloudfront_cache_policy.main.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.main.id
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

resource "aws_s3_bucket_policy" "main" {
  bucket = var.bucket_id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action = "s3:GetObject"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
        }
      }
      Resource = "${var.bucket_arn}/*"
      }
    ]
  })
}
locals {
  alb_origin_id = "${var.name_prefix}-alb"
  s3_origin_id  = "${var.name_prefix}-s3"
}

data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "main" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "main" {
  name = "Managed-AllViewer"
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
  name                              = "${var.name_prefix}-frontend"
}
