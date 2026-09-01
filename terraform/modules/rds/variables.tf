variable "name_prefix" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "security_group_id" {
  type = string
}

variable "db_name" {
  type    = string
  default = "watchfloordb"
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_username" {
  type    = string
  default = "watchfloor"
}
