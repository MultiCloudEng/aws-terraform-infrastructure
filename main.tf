terraform {
 backend "s3" {  

 bucket = "asabucket-1204"
 key = "terraform.tfstate"
 region = "eu-north-1"
 }
}


provider "aws" {
  region = var.region
}

resource "aws_security_group" "my_sg" {
  name = "allow_ssh"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


module "web" {
  source           = "./modules/server"
  ami_id           = var.ami_id
  instance_type    = var.instance_type
  security_group_id = aws_security_group.my_sg.id
  name             = "web"
}

module "api" {
  source           = "./modules/server"
  ami_id           = var.ami_id
  instance_type    = var.instance_type
  security_group_id = aws_security_group.my_sg.id
  name             = "api"
}

