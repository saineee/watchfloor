variable "alb_dns_name" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "cloudfront_header" {
  type      = string
  sensitive = true
}

variable "bucket_regional_domain_name" {
  type = string
}

variable "bucket_arn" {
  type = string
}

variable "bucket_id" {
  type = string
}
