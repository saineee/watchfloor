variable "name_prefix" {
  type    = string
  default = "watchfloor"
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "anthropic_federation_rule_id" {
  type    = string
  default = "fdrl_01HcojYraSeruSsfENyU1tpW"
}

variable "anthropic_organization_id" {
  type    = string
  default = "cbe93df6-d9eb-4e8f-a800-d096526a1ec5"
}

variable "anthropic_service_account_id" {
  type    = string
  default = "svac_014e5jnfu9yXTxhYca8GMAM7"
}

variable "anthropic_workspace_id" {
  type    = string
  default = "wrkspc_0159bmAqzTYEw2ke7kcvFew9"
}
