variable "region" {
  default = "us-east-1"
}
variable "instance_type" {
  default = "t3a.micro"
}
variable "ami_owner" {
}
variable "ami_name" {
}
variable "docker_compose_version" {
  
}
variable "ssh_user" {
  description = "The user to ssh in as"
  default = "root"
}
variable "ssh_public_key_location" {
  description = "The location of public part of the key that will be allowed to SSH in"
  default = "~/.ssh/id_rsa.pub"
}
variable "ssh_access_cidr" {
  description = "The ip cidr that will be allowed to SSH in"
}
variable "vpn_protocol" {
  description = "The protocol for the VPN to work over. Valid values are udp or tcp"
}
variable "vpn_port" {
  description = "The port for the VPN to listen on"
  type = number
}