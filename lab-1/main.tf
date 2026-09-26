provider "aws" {
    region = "us-east-1"
}

resource "aws_instance" "this" {
  ami = var.ami_id
  instance_type = var.instance_type

  tags = {
    Name = var.ec2_name
  }
}