# terraform
terraform poc

**You have to launch an application by creating the following infrastructure using Terraform ( as much as possible )**

  1.First create a key, then create a security group which allows port 80
  
  2.Then launch an EC2 instance using the firewall and key created above
  
  3.Create an EBS Volume and mount it on /var/www/html
  
  4.You have a github repo, download that code from there into the /var/www/html folder
  
  5.There are a few images on that github repo, download them into an s3 bucket
  
  6.Create a cloud front for the above s3
  
  7.Update the Cloud front URL into the code that was downloaded into the above folder which is accessible publically
