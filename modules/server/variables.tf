variable "ami_id" {}
variable "instance_type" {}
variable "security_group_id" {}
variable "name" {}
variable "subnet_ids" {
  type = list(string)
}
