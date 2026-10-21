variable "name_prefix" {
  type    = string
  default = "watchfloor"
}

variable "anthropic_federation_rule_id" {
  type = string
}

variable "anthropic_organization_id" {
  type = string
}

variable "anthropic_service_account_id" {
  type = string
}

variable "anthropic_workspace_id" {
  type = string
}

variable "enable_cloudfront" {
  type    = bool
  default = false
}
