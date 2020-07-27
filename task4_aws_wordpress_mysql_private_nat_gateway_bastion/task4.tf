


provider "aws" {
	region="ap-south-1"
	profile="default"
}


# Main vpc

resource "aws_vpc" "main_vpc" {
	cidr_block="192.168.0.0/16"
	instance_tenancy="default"
	enable_dns_hostnames="true"
	tags = {
		Name="main_vpc"
	}
}

# Private subnet
resource "aws_subnet" "private_subnet" {
	vpc_id=aws_vpc.main_vpc.id
	cidr_block="192.168.1.0/24"
	availability_zone="ap-south-1b"
	tags = {
		Name="private_subnet"
	}
}

# Public subnet
resource "aws_subnet" "public_subnet" {
	vpc_id=aws_vpc.main_vpc.id
	cidr_block="192.168.0.0/24"
	map_public_ip_on_launch="true"
	availability_zone="ap-south-1a"
	tags = {
		Name="public_subnet"
	}
}

# Internet gateway

resource "aws_internet_gateway" "main_ig" {
	vpc_id=aws_vpc.main_vpc.id
	tags = {
		Name="main_ig"
	}
}

# Routing table

resource "aws_route_table" "main_rt" {
	vpc_id=aws_vpc.main_vpc.id

	route {
		cidr_block="0.0.0.0/0"
		gateway_id=aws_internet_gateway.main_ig.id
	}

	tags = {
		Name="main_rt"
	}
}

# Route table association

resource "aws_route_table_association" "pub_rt_assoc" {
	subnet_id=aws_subnet.public_subnet.id
	route_table_id=aws_route_table.main_rt.id
}


# RSA keypair for ssh

resource "tls_private_key" "main_key" {
	algorithm="RSA"
}

module "key_pair" {
	source="terraform-aws-modules/key-pair/aws"
	key_name="main_key"
	public_key=tls_private_key.main_key.public_key_openssh
}

# Security groups

# Security group for public subnet

resource "aws_security_group" "pub_sg" {
	name="pub_sg"
	vpc_id=aws_vpc.main_vpc.id

	ingress {
		description="Allow ssh on port 22"
		from_port=22
		to_port=22
		protocol="tcp"
		cidr_blocks=["0.0.0.0/0"]
	}

	ingress {
		description="Allow http on port 80"
		from_port=80
		to_port=80
		protocol="tcp"
		cidr_blocks=["0.0.0.0/0"]
	}

	egress {
		from_port=0
		to_port=0
		protocol="-1"
		cidr_blocks=["0.0.0.0/0"]
	}

	tags = {
		Name="pub_sg"
	}
}

# Security group for bastion host

resource "aws_security_group" "bastion_sg" {
	name="bastion_sg"
	vpc_id=aws_vpc.main_vpc.id

	ingress {
		description = "ssh on port 22"
		from_port=22
		to_port=22
		protocol="tcp"
		cidr_blocks=["0.0.0.0/0"]
	}

	ingress {
		from_port=0
		to_port=0
		protocol="-1"
		cidr_blocks=["192.168.1.0/24"]
	}

	egress {
		from_port=0
		to_port=0
		protocol="-1"
		cidr_blocks=["0.0.0.0/0"]
	}

	tags = {
		Name="bastion_sg"
	}
}

# Security group for private subnet

resource "aws_security_group" "priv_sg" {
	name="priv_sg"
	vpc_id=aws_vpc.main_vpc.id

	ingress {
		description="TLS on port 3306"
		from_port=3306
		to_port=3306
		protocol="tcp"
		security_groups=[aws_security_group.pub_sg.id]
	}

	ingress {
		from_port=0
		to_port=0
		protocol="-1"
		security_groups=[aws_security_group.bastion_sg.id]
	}

	egress {
		from_port=0
		to_port=0
		protocol="-1"
		cidr_blocks=["0.0.0.0/0"]
	}

	tags = {
		Name="priv_sg"
	}
}

# EC2 instances

# EC2 instance for worpress

resource "aws_instance" "wp_instance" {
	ami="ami-004a955bfb611bf13"
	instance_type="t2.micro"
	subnet_id=aws_subnet.public_subnet.id
	vpc_security_group_ids=[aws_security_group.pub_sg.id]
	key_name="task4_key"
	tags = {
		Name="wp_instance"
	}
}

# EC2 instance for bastion host

resource "aws_instance" "bastion_instance" {
	ami="ami-0732b62d310b80e97"
	instance_type="t2.micro"
	subnet_id=aws_subnet.public_subnet.id
	key_name="task4_key"
	vpc_security_group_ids=[aws_security_group.bastion_sg.id]

	tags = {
		Name="bastion_instance"
	}
}

# EC2 instance for mysql

resource "aws_instance" "mysql_instance" {
	ami="ami-08706cb5f68222d09"
	instance_type="t2.micro"
	subnet_id=aws_subnet.private_subnet.id
	vpc_security_group_ids=[aws_security_group.priv_sg.id]
	key_name="task4_key"
	tags = {
		Name="mysql_instance"
	}
}

# EIP

resource "aws_eip" "nat" {
	vpc=true
}

# NAT gateway

resource "aws_nat_gateway" "nat_gw" {
	depends_on=[
		aws_instance.mysql_instance,
	]

	allocation_id=aws_eip.nat.id
	subnet_id=aws_subnet.public_subnet.id

	tags = {
		Name="nat_gw"
	}
}

# Private route table

resource "aws_route_table" "private_rt" {
	depends_on=[
		aws_nat_gateway.nat_gw,
	]
	vpc_id=aws_vpc.main_vpc.id

	route {
		cidr_block="0.0.0.0/0"
		gateway_id=aws_nat_gateway.nat_gw.id
	}

	tags = {
		Name = "private_rt"
	}
}

# Private route table association

resource "aws_route_table_association" "priv_rt_assoc" {
	depends_on = [
		aws_route_table.private_rt
	]

	subnet_id=aws_subnet.private_subnet.id
	route_table_id=aws_route_table.private_rt.id
}

# Local-exec for write main_key to pem file locally

resource "null_resource" "write_key" {
	depends_on = [
		tls_private_key.main_key
	]

	provisioner "local-exec" {
		command="echo '${tls_private_key.main_key.private_key_pem}' > main_key.pem"
	}
}
