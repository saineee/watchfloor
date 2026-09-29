variable "name_prefix" {
  type = string
}

variable "permissions_boundary" {
  type = string
}

variable "graf_pass_arn" {
  type = string
}

variable "account_id" {
  type = string
}

variable "prom_cloudmap" {
  type = string
}

variable "graf_cloudmap" {
  type = string
}

variable "am_cloudmap" {
  type = string
}

variable "cpu" {
  type    = number
  default = 256
}

variable "memory" {
  type    = number
  default = 512
}

variable "cluster_arn" {
  type = string
}

variable "private_subnets_ids" {
  type = list(string)
}

variable "alertmanager_sg" {
  type = string
}
