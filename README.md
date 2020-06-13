# terraform
terraform poc

**You have to launch an application by creating the following infrastructure using Terraform ( InfrastructureAsACode )**

  1.First create a key, then create a security group which allows port ssh 22 and http 80
  
  2.Then launch an EC2 instance using the firewall and key created above
  
  3.Create an EBS Volume , attach EBS to EC2 and mount it on /var/www/html
  
  4.from github repo, download the code from there into the /var/www/html folder on ec2
  
  5. Create s3 bucket , download images locally from s3 bucketa and upload it an s3 bucket

  6. create cloudfront distribution to server website content hosted on s3 bucket

  7.Update the Cloud front URL into the code that was downloaded into the above folder which is accessible publically
