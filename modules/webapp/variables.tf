
variable "vpc_name" {}
variable "vpc_cidr" {}
variable "subnet_cidr" {}

variable "instance_name" {}
variable "ami_id" {}
variable "instance_type" {}
variable "key_name" {}
variable "private_ip" {}

variable "ebs_size" {
  default = 500
}
