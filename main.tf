provider "aws" {
  region  = "ap-south-1"
  profile = "default"
}

resource "aws_instance" "myec2"{
  ami = "ami-0447a12f28fddb066" 
  instance_type = "t2.micro"
  key_name = "mykey1"
  security_groups = ["allow_ssh_and_http"]
  user_data = "${file("install_apache.sh")}"  
  
  tags = {
    Name = "firstos"
  }
}
output "myoutput" {
    value = aws_instance.myec2.availability_zone
}

// create EBS volume 
resource "aws_ebs_volume" "myvolume" {
  availability_zone = "ap-south-1a"
  size              = 1
}


// attach EBS volume 
resource "aws_volume_attachment" "ebs_attach" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.myvolume.id}"
  instance_id = "${aws_instance.myec2.id}"
}

// create s3 bucket

resource "aws_s3_bucket" "mybucket" {
  bucket = "mybucket-awjun09"
  acl    = "private"
  }


output "s3_bucket" {
  value = aws_s3_bucket.mybucket
}

// create cloudfront

locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.mybucket.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"

    s3_origin_config {
      origin_access_identity = "origin-access-identity/cloudfront/ABCDEFG1234567"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

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

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "cloudfront" {
  value = aws_cloudfront_distribution.s3_distribution
}


// assing EIP to EC2
resource "aws_eip" "my_eip" {
  instance = "${aws_instance.myec2.id}"
  vpc      = true
}

output "myEIP" {
  value = aws_eip.my_eip
}

// create security group
resource "aws_security_group" "mysecuritygroup" {
  name        = "allow_ssh_and_http"
  description = "Allow SSH and HTTP inbound traffic"

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
	cidr_blocks = ["0.0.0.0/0"]
	    
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysecuritygroup"
  }
}

output "mysg_id" {
    value = aws_security_group.mysecuritygroup
}

