terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.20.0"
    }
  }
}

provider "aws" {
  # Configuration options
  region = "us-east-1"
}

############### VPC ##########################

resource "aws_vpc" "wordpress_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    "Name" = "wordpress-vpc"
  }
}

########## public subnets ########################
resource "aws_subnet" "public-subnet-1" {
  vpc_id                  = aws_vpc.wordpress_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-1"
  }
}
resource "aws_subnet" "public-subnet-2" {
  vpc_id                  = aws_vpc.wordpress_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-2"
  }
}
resource "aws_subnet" "public-subnet-3" {
  vpc_id                  = aws_vpc.wordpress_vpc.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-3"
  }
}
########### private subnets ##################
resource "aws_subnet" "private-subnet-1" {
  vpc_id                  = aws_vpc.wordpress_vpc.id
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = false
  tags = {
    Name = "private-1"
  }
}

resource "aws_subnet" "private-subnet-2" {
  vpc_id                  = aws_vpc.wordpress_vpc.id
  cidr_block              = "10.0.5.0/24"
  map_public_ip_on_launch = false
  tags = {
    Name = "private-2"
  }
}

resource "aws_subnet" "private-subnet-3" {
  vpc_id                  = aws_vpc.wordpress_vpc.id
  cidr_block              = "10.0.6.0/24"
  map_public_ip_on_launch = false
  tags = {
    Name = "private-3"
  }
}

############# IG #########################

resource "aws_internet_gateway" "wordpress-igw" {
  vpc_id = aws_vpc.wordpress_vpc.id
  tags = {
    "Name" = "wordpress-igw"
  }
}

############# RT #######################

resource "aws_route_table" "wordpress-rt" {
  vpc_id = aws_vpc.wordpress_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wordpress-igw.id
  }

  tags = {
    "Name" = "wordpress-rt"
  }
}

resource "aws_route_table_association" "wp-rt-subnet-1" {
  route_table_id = aws_route_table.wordpress-rt.id
  subnet_id      = aws_subnet.public-subnet-1.id
}
resource "aws_route_table_association" "wp-rt-subnet-2" {
  route_table_id = aws_route_table.wordpress-rt.id
  subnet_id      = aws_subnet.public-subnet-2.id
}
resource "aws_route_table_association" "wp-rt-subnet-3" {
  route_table_id = aws_route_table.wordpress-rt.id
  subnet_id      = aws_subnet.public-subnet-3.id
}
############## SG ###############################

resource "aws_default_security_group" "wordpress-sg" {
  vpc_id = aws_vpc.wordpress_vpc.id
  dynamic "ingress" {
    for_each = [22, 80, 433]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    "Name" = "wordpress-sg"
  }
}

########### ssh key ########################

resource "aws_key_pair" "key" {
  key_name   = "key"
  public_key = file("~/.ssh/id_rsa.pub")
}

#########  EC2 #####################

resource "aws_instance" "ec2" {
  ami           = data.aws_ami.latest_ami.id # "ami-067d1e60475437da2"
  instance_type = "t2.micro"

  subnet_id                   = aws_subnet.public-subnet-1.id
  vpc_security_group_ids      = [aws_default_security_group.wordpress-sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.key.key_name

  tags = {
    "Name" = "wordpress-ec2"
  }
}
################ data ###############
data "aws_ami" "latest_ami" {
  owners      = ["amazon"]
  most_recent = true #optional
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-x86_64-gp2"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
########### RDS Security Group ################################

resource "aws_security_group" "rds-sg" {
  vpc_id = aws_vpc.wordpress_vpc.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_default_security_group.wordpress-sg.id]
  }
  tags = {
    "Name" = "rds-sg"
  }
}

########### db subnets #####################

resource "aws_db_subnet_group" "private_db_subnets" {
  name       = "db_subnets"
  subnet_ids = [aws_subnet.private-subnet-1.id, aws_subnet.private-subnet-2.id, aws_subnet.private-subnet-3.id]

  tags = {
    "Name" = "My DB subnet group"
  }
}


######### MySQL DB #####################


resource "aws_db_instance" "mysql_db" {
  allocated_storage      = 20
  db_name                = "wordpress"
  engine                 = "mysql"
  storage_type           = "gp2"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  username               = "admin"
  password               = "adminadmin"
  parameter_group_name   = "default.mysql5.7"
  vpc_security_group_ids = [aws_security_group.rds-sg.id]
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.private_db_subnets.name
  tags = {
    "Name" = "wordpress-mysql-db"
  }
}




