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
