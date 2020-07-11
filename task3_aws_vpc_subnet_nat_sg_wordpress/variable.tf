variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default = "10.0.0.0/16"
}
variable "pub_cidr_subnet" {
  description = "CIDR block for the subnet"
  default = "10.0.0.0/24"
}
variable "pvt_cidr_subnet" {
  description = "CIDR block for the subnet"
  default = "10.0.1.0/24"
}
variable "availability_zone" {
  description = "availability zone to create subnet"
  default = "ap-south-1a"
}
variable "public_key_path" {
  description = "Public key path"
  default = "~/Downloads/mykey_ap_south_1.ppk"
}
variable "wordpress_instance_ami" {
  description = "AMI for aws EC2 instance"
  default = "ami-052c08d70def0ac62"
}
variable "bastion_instance_ami" {
  description = "AMI for aws EC2 instance"
  default = "ami-052c08d70def0ac62"
}
variable "mysql_instance_ami" {
  description = "AMI for aws EC2 instance"
  default = "ami-052c08d70def0ac62"
}
variable "wordpress_instance_type" {
  description = "type for aws EC2 instance"
  default = "t2.micro"
}
variable "bastion_instance_type" {
  description = "type for aws EC2 instance"
  default = "t2.micro"
}
variable "mysql_instance_type" {
  description = "type for aws EC2 instance"
  default = "t2.micro"
}
variable "env_tag" {
  description = "Environment tag"
  default = "awtest"
}