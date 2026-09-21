variable "name_prefix" {
  type    = string
  default = "watchfloor"
}

variable "email" {
  sensitive = true
  type      = string
}

variable "paul_user" {
  type    = string
  default = "arn:aws:iam::330866750121:user/paul"
}
