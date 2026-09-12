variable "name_prefix" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "image" {
  type = string
}

variable "container_port" {
  type    = number
  default = 8000
}

variable "cpu" {
  type    = number
  default = 256
}

variable "memory" {
  type    = number
  default = 512
}

variable "database_url_ssm_arn" {
  type = string
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

variable "secret_key_ssm_arn" {
  type = string
}

variable "permissions_boundary" {
  type = string
}
