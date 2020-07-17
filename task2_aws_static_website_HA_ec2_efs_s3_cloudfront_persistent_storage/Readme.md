Task-2

Perform the task-1 using EFS instead of EBS service on the AWS as,
Create/launch Application using Terraform

1. Create Security group which allow the port 80.
2. Launch EC2 instance.
3. In this Ec2 instance use the existing key or provided key and security group which we have created in step 1.
4. Launch one Volume using the EFS service and attach it in your vpc, then mount that volume into /var/www/html
5. Developer have uploded the code into github repo also the repo has some images.
6. Copy the github repo code into /var/www/html
7. Create S3 bucket, and copy/deploy the images from github repo into the s3 bucket and change the permission to public readable.
8 Create a Cloudfront using s3 bucket(which contains images) and use the Cloudfront URL to  update in code in /var/www/html

Optional
1) Those who are familiar with jenkins or are in devops AL have to integrate jenkins in this task wherever you feel can be integrated

Task-2 Link:  https://forms.gle/xXNS9Kgj6Lb97utt7




# Task-2 Automating Services With Terraform

here we are creating a complete automated architecture consisting of AWS Instances, AWS Storage(EBS and S3) through terraform. 
This task is part of Hybrid Multi Cloud Training by Vimal Daga Sir

Architecture:

## Task Description:
1. Create Security group which allow the port 80.
2. Launch EC2 instance.
3. In this Ec2 instance use the existing key or provided key and security group which we have created in step 1.
4. Launch one Volume using the EFS service and attach it in your vpc, then mount that volume into /var/www/html
5. Developer have uploded the code into github repo also the repo has some images.
6. Copy the github repo code into /var/www/html
7. Create S3 bucket, and copy/deploy the images from github repo into the s3 bucket and change the permission to public readable.
8 Create a Cloudfront using s3 bucket(which contains images) and use the Cloudfront URL to  update in code in /var/www/html

Usage of Terraform commands 
- To download provider and resource plugins:
> terraform init



To create this setup:
First we have to write providers- here AWS
```
provider "aws" {
  region     = "ap-south-1"
  profile    = "default"
}
```

## Create VPC and Subnet:

```
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

```
## As we are using custom vpc we need to add internet gateway to access ec2 instance from out side world

```

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


```

## Security Group:

Security Group to allow port no. 80 for httpd, 22 for ssh and 2049 for NFS

```
resource "aws_security_group" "task2_sg" {
  vpc_id = "${aws_vpc.task2vpc.id}"

  
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
  
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
  }   
  
  tags = {
    Name = "task2_sg"
  }  
}

```


## Launch EC2 Instance:

Here we are launching an EC2 instance “webserver_instance” and installing necessary packages also by using provisioner we installing amazon-efs-utils.
```
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
      "sudo mount -a -t efs,ns4 defaults",
	  "sudo rm -rf /var/www/html/*",
	  "sudo git clone https://github.com/ashishw99/mywebsite /var/www/html"
    ]
  }
  
  
 tags = {
   Name = "webserver_instance"
 }
}
```
## To upload image files on s3 bucket , we need to download a copy of images in local

```
```
## Create EFS Volume:


Creating an efs volume in the default VPC and same security group as of instance. And then attach it to ec2 instance .
```
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


```


## S3 Bucket:


Now, We create a S3 bucket to store our files permanently.After creating bucket we have to place images in this so we will clone github repo in a folder at local system and then upload it.To upload object in S3 bucket we have to first add some permissions and then we can upload objects.

```
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
```


# To restrict bucket policy to only Read files
```

resource "aws_s3_bucket_policy" "policy" {
  bucket = "${aws_s3_bucket.taskbucket.id}"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "BUCKETPOLICY",
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

```
To upload object:
```
resource "aws_s3_bucket_object" "object" {
  bucket = "ashishbucket20200717"
  key    = "s3image.jpg"
  source = "mywebsite/s3image.jpg"
  acl = "public-read"
  content_disposition = "inline"
  content_encoding = "base64"
  
}
```

## CloudFront Distribution:

creating OAI to restrict bucket policy to access only from cloudfront
```
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "task 2"
}

```

Creating Cloud Front distributions and adding cache behaviours,restrictions and some policies.
```
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

```


We can update image url in index.html file in instance manually.
And then finally displaying webpage using instance ip
```
resource "null_resource" "launch_website"  {

depends_on = [
       aws_cloudfront_distribution.s3_distribution
   
  ]

	provisioner "local-exec" {
	    
            command = "start chrome  ${aws_instance.webserver.public_ip}"
  	}
}
```

- To create infrastructure:
> terraform apply


- To create infrastructure without any confirmation prompt:
> terraform apply -auto-approve


- To destroy the complete infrastructure:
> terraform destroy

*Thank You!!*









