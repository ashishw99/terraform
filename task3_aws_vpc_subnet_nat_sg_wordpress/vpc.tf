provider "aws" {
  region = "ap-south-1"
  profile = "default"
}


resource "aws_vpc" "awvpc" {
  cidr_block = "${var.vpc_cidr}"
  enable_dns_hostnames = "true"
  instance_tenancy = "default"
  tags = {
    Environment = "${var.env_tag}"
	Name = "aws_vpc"
  }  
}

resource "aws_subnet" "public_subnet" {
depends_on = [aws_vpc.awvpc]
  vpc_id = "${aws_vpc.awvpc.id}"
  cidr_block = "${var.pub_cidr_subnet}"
  map_public_ip_on_launch = "true"
  availability_zone = "${var.availability_zone}"
  tags = {
    Environment = "${var.env_tag}"
	Name = "aw_public_subnet"
  }
}

resource "aws_subnet" "private_subnet" {
depends_on = [aws_vpc.awvpc]
  vpc_id = "${aws_vpc.awvpc.id}"
  cidr_block = "${var.pvt_cidr_subnet}"
  availability_zone = "${var.availability_zone}"
  tags = {
    Environment = "${var.env_tag}"
	Name = "aw_private_subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.awvpc.id}"
  tags = {
    Environment = "${var.env_tag}"
	Name = "aw_igw"
  }
}

resource "aws_route_table" "routetable_public" {
  vpc_id = "${aws_vpc.awvpc.id}"
  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.igw.id}"
  }
  tags = {
    Environment = "${var.env_tag}"
	Name = "aw_public_route"
  }
}

resource "aws_route_table_association" "routetable_subnet_public_asso" {
  subnet_id      = "${aws_subnet.public_subnet.id}"
  route_table_id = "${aws_route_table.routetable_public.id}"    
}

resource "aws_security_group" "public_sg" {
  vpc_id = "${aws_vpc.awvpc.id}"
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }  

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }
  
  tags = {
    Name = "aw_public_sg"
  }  
}

output "public_sg"{
value = aws_security_group.public_sg.id
}

resource "aws_security_group" "privatsg" {
  vpc_id = "${aws_vpc.awvpc.id}"
  ingress {
    cidr_blocks = ["${var.pub_cidr_subnet}"]
	from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  } 

  ingress {
    cidr_blocks = ["${var.pub_cidr_subnet}"]
	from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
  }  
  
  tags = {
    Name = "aw_private_sg"
  }
}



resource "tls_private_key" "mytls" {
  algorithm   = "RSA"
}
output "openssh_key"{
value = tls_private_key.mytls.public_key_openssh

}
output "pem_key"{
value = tls_private_key.mytls.private_key_pem
}

resource "aws_key_pair" "ec2key" {
  key_name   = "ec2key"
  public_key = tls_private_key.mytls.public_key_openssh
}


resource "aws_instance" "wordpress" {
  ami           = "${var.wordpress_instance_ami}"
  instance_type = "${var.wordpress_instance_type}"
  subnet_id = "${aws_subnet.public_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.public_sg.id}"]
  key_name = "${aws_key_pair.ec2key.key_name}"
  
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.mytls.private_key_pem
    host     = aws_instance.wordpress.public_ip
  }

  provisioner "remote-exec" {
    inline = [
 #     "sudo yum update -y ",
 #     "sudo amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2",
 #     "sudo yum install -y httpd mariadb-server",
 #     "sudo systemctl start httpd && sudo systemctl enable httpd"
    ]
  }
  
  
 tags = {
  Environment = "${var.env_tag}"
   Name = "wordpress_instance"
 }
}


resource "aws_instance" "mysql" {
  ami           = "${var.mysql_instance_ami}"
  instance_type = "${var.mysql_instance_type}"
  subnet_id = "${aws_subnet.private_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.public_sg.id}"]
  key_name = "${aws_key_pair.ec2key.key_name}"
  
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.mytls.private_key_pem
    host     = aws_instance.mysql.public_ip
  }

  provisioner "remote-exec" {
    inline = [
#      "sudo yum update -y ",
#      "sudo amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2",
#      "sudo yum install -y mariadb-server"
    ]
  }
 
 
 tags = {
  Environment = "${var.env_tag}"
  Name = "mysql_instance"
 }
}

resource "aws_instance" "nat_instance" {
  ami           = "${var.bastion_instance_ami}"
  instance_type = "${var.bastion_instance_type}"
  subnet_id = "${aws_subnet.public_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.public_sg.id}"]
  key_name = "${aws_key_pair.ec2key.key_name}"
 tags = {
  Environment = "${var.env_tag}"
  Name = "nat_instance"
 }
}


resource "aws_eip" "elastic_ip" {
  instance = "${aws_instance.nat_instance.id}"
  vpc      = true
}

output "eip" {
value= aws_eip.elastic_ip.id

}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = "${aws_instance.nat_instance.id}"
  allocation_id = "${aws_eip.elastic_ip.id}"
}


resource "aws_route_table" "routetable_private" {
  vpc_id = "${aws_vpc.awvpc.id}"
  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_nat_gateway.nat_gateway.id}"
  }
  tags = {
    Environment = "${var.env_tag}"
	Name = "aw_private_route"
  }
}

resource "aws_route_table_association" "routetable_subnet_private_asso" {
  subnet_id      = "${aws_subnet.private_subnet.id}"
  route_table_id = "${aws_route_table.routetable_private.id}"    
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = "${aws_eip.elastic_ip.id}"
  subnet_id     = "${aws_subnet.public_subnet.id}"

  tags = {
    Name = "NAT gateway"
  }
}

