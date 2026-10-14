resource "aws_cloudfront_distribution" "main" {
  enabled = true
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
  default_cache_behavior {
    target_origin_id         = local.alb_origin_id
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD"]
    viewer_protocol_policy   = "redirect-to-https"
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.main.id
    cache_policy_id          = data.aws_cloudfront_cache_policy.main.id
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



locals {
  alb_origin_id = "${var.name_prefix}-alb"
}

data "aws_cloudfront_cache_policy" "main" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "main" {
  name = "Managed-AllViewer"
}
