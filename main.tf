provider "aws" {
  region = "ap-south-1"
  profile = "default"
 
 }

resource "tls_private_key" "mykey" {
  algorithm = "RSA"
}
output "key_ssh" {
  value = tls_private_key.mykey.public_key_openssh
}

output "key_pem" {
  value = tls_private_key.mykey.public_key_pem
}

resource "aws_key_pair" "opensshkey"{
  key_name = "mykey"
  public_key = tls_private_key.mykey.public_key_openssh
}

resource "aws_security_group" "mysg" {

    name = "my_security_group"
	description = "Allow http traffic on port 80 and ssh on port 22."

	ingress { 
		description = "http on port 80."
		from_port = 80
		to_port = 80
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	ingress { // Check
		description = "ssh on port 22."
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	egress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}

}

resource "aws_instance" "myec2instance" {
depends_on = [
  aws_security_group.mysg
]

  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = aws_key_pair.mykey.key_name
  security_groups = [ aws_security_group.mysg.name]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.mykey.private_key_pem
    host     = aws_instance.myec2instance.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "myec2"
  }
}

output "mypublic_ip" {
  value = aws_instance.myec2instance.public_ip
}


resource "aws_ebs_volume" "myebsvolume" {
  availibility_zone = aws_instance.myec2instance.availability_zone
  size = 1
  tags {
    Name = "myebsvolume"
  }
}

resource "aws_volume_attachment" "ebs_attach" {
depends_on = [
  aws_ebs_volume.myebsvolume
]
  device_name = "/dev/sdf"
  volume_id = aws_ebs_volume.myebsvolume.id
  instance_id = aws_instance.myec2instance.id
  force_detach = true
}


resource "null_resource" "create_partition" {
depends_on = [
  aws_volume_attachment.ebs_attach
]
  connection {
    type = "ssh"
	user = "ec2-user"
	private_key = tls_private_key.my.private_key_pem
	host = aws_instance.myec2instance.public_ip
  }
  
  provisioner "remote-exec" {
    inline = [
	  "sudo mkfs.ext4 /dev/xvdf",
	  "sudo mount /dev/xvdf /var/www/html",
	  "sudo rm -rf /var/www/html/*",
	  "sudo git clone https://github.com/ashishw99/mywebsite.git /var/www/html/",
	
	]
  
  }

}


resource "aws_s3_bucket" "mywebsitebucket" {
  bucket_name = "mywebsitebucket_ashishjune2020"
  acl = "public-read"
  tags = {
    Name =  "mywebsitebucket"
  }  
}

resource "null_resource" "download-s3image" { 
  provisioner "local-exec" {
    inline = [
	  "git clone https://github.com/ashishw99/s3image.git"
	]
  }
}

resource "aws_s3_bucket_object" "myimage" {
depends_on = [
  aws_s3_bucket.mywebsitebucket,
  null_resource.download-s3image
]
  bucket = "mywebsitebucket_ashishjune2020"
  key = "s3image.jpg"
  source = "s3image.jpg"
  etag = filemd5("s3image.jpg")
  acl = "public-read-write"
}

locals {
	s3_origin_id = "s3-origin"
}

resource "aws_cloudfront_distribution" "cloudfront-url" {
depends_on = [
aws_s3_bucket_object.image-jpg,
]
	enabled = true
	is_ipv6_enabled = true
	
	origin {
		domain_name = aws_s3_bucket.mywebsitebucket.bucket_regional_domain_name
		origin_id = local.s3_origin_id
	}

	restrictions {
		geo_restriction {
			restriction_type = "none"
		}
	}

	default_cache_behavior {
		target_origin_id = local.s3_origin_id
		allowed_methods = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    	cached_methods  = ["HEAD", "GET", "OPTIONS"]

    	forwarded_values {
      		query_string = false
      		cookies {
        		forward = "none"
      		}
		}

		viewer_protocol_policy = "redirect-to-https"
    	min_ttl                = 0
    	default_ttl            = 120
    	max_ttl                = 86400
	}

	viewer_certificate {
    	cloudfront_default_certificate = true
  	}
}
output "mycloudfront"{
value     = aws_cloudfront_distribution.cloudfront-url.domain_name
}


resource "remote-exec" "update-index-with-cloudfront-url" {
depends_on = [
  aws_cloudfront_distribution.cloudfront-url,
  aws_ebs_volume.myebsvolume,
  aws_instance.myec2instance,
  aws_key_pair.mykey
 ] 
  connection {
    type = "ssh"
	user = "ec2-user"
	private_key = tls_private_key.my.private_key_pem
	host = aws_instance.myec2instance.public_ip
  }
  
  provisioner "remote-exec" {
    command = "sudo echo Hurray my website is live > test.html "
  
  }


}


resource "null_resource" "store_ip"  {
depends_on = [
  aws_instance.myec2instance
]
	provisioner "local-exec" {
	  resource "null_resource" "remote2"  {  
	    command = "echo  ${aws_instance.myec2instance.public_ip} > mywebsite_ipaddress.txt"
  	}
}
}

resource "null_resource" "launch_website_locally"  {
depends_on = [
    null_resource.create_partition,
	aws_instance.myec2instance,
	aws_ebs_volume.myebsvolume
  ]

	provisioner "local-exec" {
	    command = "chrome  ${aws_instance.mytask1instance.public_ip}/test.html"
  	}
}
