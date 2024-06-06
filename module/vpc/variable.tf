variable "cidr_block" {
  type = string
}

variable "public_subnet_count" {
  type = number
}

variable "public_subnets_cidr_blocks" {
  type = list(string)
}

variable "private_subnet_count" {
  type = number
}

variable "private_subnets_cidr_blocks" {
  type = list(string)
}

variable "availability_zones" {
  type = list(string)
}
