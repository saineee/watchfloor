variable "name_prefix" {
  type = string
}

variable "efs_sg_id" {
  type = string
}

variable "private_subnets_ids" {
  type = list(string)
}
