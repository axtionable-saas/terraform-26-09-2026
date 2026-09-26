provider "aws" {
    region = "us-east-1"
}

resource "aws_vpc" "this" {
  cidr_block = "10.140.0.0/16"

  tags = {
    Name = "Lab-2 VPC"
  }
}

resource "aws_subnet" "public-1a" {
    vpc_id = aws_vpc.this.id
    cidr_block = "10.140.0.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true

    tags = {
        Name = "Lab-2 Public Subnet - 1a"
    }
}

resource "aws_subnet" "public-1b" {
    vpc_id = aws_vpc.this.id
    cidr_block = "10.140.1.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true

    tags = {
        Name = "Lab-2 Public Subnet - 1b"
    }
}

resource "aws_subnet" "private-1a" {
    vpc_id = aws_vpc.this.id
    cidr_block = "10.140.2.0/24"
    availability_zone = "us-east-1a"

    tags = {
        Name = "Lab-2 Private Subnet - 1a"
    }
}

resource "aws_subnet" "private-1b" {
    vpc_id = aws_vpc.this.id
    cidr_block = "10.140.3.0/24"
    availability_zone = "us-east-1b"

    tags = {
        Name = "Lab-2 Private Subnet - 1b"
    }
}

resource "aws_internet_gateway" "this" {
    vpc_id = aws_vpc.this.id

    tags = {
        Name = "Lab-2 IGW"
    } 
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "Lab-2 Public RT"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "Lab-2 Private RT"
  }
}

resource "aws_route_table_association" "public-1a" {
  subnet_id = aws_subnet.public-1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public-1b" {
  subnet_id = aws_subnet.public-1b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private-1a" {
  subnet_id = aws_subnet.private-1a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private-1b" {
  subnet_id = aws_subnet.private-1b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "this" {
  vpc_id = aws_vpc.this.id

  ingress {
    description = "Allow SSH Access"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    description = "Allow HTTP Access"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "ALL"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  tags = {
    Name = "Lab-2 SG"
  }
}

resource "aws_instance" "this" {
  ami = var.ami_id
  instance_type = var.instance_type

  subnet_id = aws_subnet.public-1a.id
  vpc_security_group_ids = [ aws_security_group.this.id ]

  tags = {
    Name = var.ec2_name
  }
}

resource "aws_ecs_cluster" "this" {
  name = "Lab-2-ECS-Cluster"

  tags = {
    Name = "Lab-2 ECS Cluster"
  }
}

resource "aws_ecs_task_definition" "this" {
  family = "lab2-task"
  network_mode = "awsvpc"
  requires_compatibilities = [ "FARGATE" ]
  cpu = "256"
  memory = "512"
  execution_role_arn = "arn:aws:iam::485031388770:role/ecsTaskExecutionRole"

  container_definitions = jsonencode([
    {
        name = "react-project"
        image = "485031388770.dkr.ecr.us-east-1.amazonaws.com/react-project:latest"
        cpu = 256
        memory = 512
        essential = true
        portMAppings = [
            {
                containerPort = 80
                hostPort = 80
            }
        ]
    }
  ])
}

resource "aws_ecs_service" "this" {
  name = "react-project-service"
  cluster = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.id
  launch_type = "FARGATE"
  desired_count = 1

  network_configuration {
    subnets = [aws_subnet.public-1a.id, aws_subnet.public-1b.id]
    security_groups = [ aws_security_group.this.id ]
    assign_public_ip = true
  }
}