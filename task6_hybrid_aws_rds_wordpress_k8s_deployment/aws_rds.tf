provider "aws" {
  region = "ap-south-1"
  profile = "ashish"
}

resource "aws_security_group" "rds_sg" {
  name = "hybrid-wp-db"
  description = "security group for webservers"
  # Allowing only MYSQL connection port=>3306 from anywhere  
  ingress {
    description = "MYSQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  # Allowing all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "rds_sg"
  }	
}

resource "aws_db_instance" "wp-backend" {
  depends_on        = [aws_security_group.rds_sg]
  allocated_storage = 20
  storage_type      = "gp2"
  engine = "mysql"
  # Defining the Security Group Created
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  engine_version         = "5.7.30"
  instance_class         = "db.t2.micro"
  identifier           = "hybridpoc"
  name                 = "hybriddb"
  username             = "ashish"
  password             = "RedHat123"
  parameter_group_name = "default.mysql5.7"
  
  # Make the DB endpoint publicly accessible so that end point can be used
  publicly_accessible = true
  # To avoid issue while deleting infrastructure set below parameter
  skip_final_snapshot = true
  apply_immediately = true


  tags = {
    Name = "wp-backend"
  }
}

output "rdsendpoint" {
value = aws_db_instance.wp-backend.address

}