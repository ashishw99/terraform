provider "aws" {
  region = "ap-south-1"
  profile = "default"

}


resource "aws_vpc" "task2vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = "true"
  instance_tenancy = "default"
  tags = {
	Name = "task2vpc"
  }  
}

resource "aws_subnet" "task2_subnet" {
depends_on = [aws_vpc.task2vpc]
  vpc_id = "${aws_vpc.task2vpc.id}"
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone = "ap-south-1a"
  tags = {
	Name = "task2subnet"
  }
}

//Security Group to allow port no. 80 for httpd, 22 for ssh and 2049 for NFS

resource "aws_security_group" "task2_sg" {
  vpc_id = "${aws_vpc.task2vpc.id}"

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
  }   
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
    Name = "task2_sg"
  }  
}


resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.task2vpc.id}"
  tags = {
	Name = "aw_igw"
  }
}

resource "aws_route_table" "routetable_public" {
  vpc_id = "${aws_vpc.task2vpc.id}"
  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.igw.id}"
  }
  tags = {
	Name = "aw_public_route"
  }
}

resource "aws_route_table_association" "routetable_subnet_public_asso" {
  subnet_id      = "${aws_subnet.task2_subnet.id}"
  route_table_id = "${aws_route_table.routetable_public.id}"    
}


resource "aws_instance" "webserver" {
  ami           = "ami-052c08d70def0ac62"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.task2_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.task2_sg.id}"]
  key_name = "mykey"
  
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:\\Terraform\\mykey_ap_south_1.ppk")
    host     = aws_instance.webserver.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y ",
      "sudo yum install -y httpd git php amazon-efs-utils nfs-utils",
      "sudo systemctl start httpd && sudo systemctl enable httpd",
      "sudo chmod ugo+rw /etc/fstab",
	  "sudo echo '${aws_efs_file_system.efs.id}:/ /var/www/html efs tls,_netdev' >> /etc/fstab ",
	  "sudo rm -rf /var/www/html/*",
      "sudo mount -a -t efs,ns4 defaults",
	  "sudo git clone https://github.com/ashishw99/mywebsite /var/www/html"
    ]
  }
  
  
 tags = {
   Name = "webserver_instance"
 }
}

resource "aws_efs_file_system" "taskvol" {
  depends_on = [
    aws_instance.webserver
  ]
  creation_token = "volume"

  tags = {
    Name = "MyEFS"
  }
}

resource "aws_efs_mount_target" "alpha" {
  depends_on =  [
                aws_efs_file_system.taskvol
  ] 
  file_system_id = "${aws_efs_file_system.taskvol.id}"
  subnet_id      = aws_instance.webserver.subnet_id
  security_groups = [ aws_security_group.task2_sg.id ]
}





resource "aws_s3_bucket" "taskbucket" {
  bucket = "ashishbucket20200717"
  acl    = "public-read"
 
  versioning {
    enabled = true
  }

  tags = {
    Name        = "task2bucket"
  }
}




resource "aws_s3_bucket_policy" "policy" {
  bucket = "${aws_s3_bucket.taskbucket.id}"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "MYBUCKETPOLICY",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::ashishbucket20200717/*"
      }
  ]
}
POLICY
}


resource "aws_s3_bucket_object" "object" {
  bucket = "ashishbucket20200717"
  key    = "s3image.jpg"
  source = "mywebsite/s3image.jpg"
  acl = "public-read"
  content_disposition = "inline"
  content_encoding = "base64"
  
}



resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.taskbucket.bucket_regional_domain_name}"
    origin_id   = "S3-ashishbucket20200717"
}

  enabled             = true
  default_root_object = "s3image.jpg"

default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-ashishbucket20200717"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
     }
  }
  tags = {
    Environment = "production"
  }
viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "task 1"
}


resource "null_resource" "launch_website"  {

depends_on = [
       aws_cloudfront_distribution.s3_distribution
   
  ]

	provisioner "local-exec" {
	    
            command = "start chrome  ${aws_instance.webserver.public_ip}"
  	}
}
