variable "name_prefix" {
  type    = string
  default = "watchfloor"
}

variable "email" {
  sensitive = true
  type      = string
}
