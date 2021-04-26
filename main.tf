provider "aws" {
  profile = "default"
  region  = var.region
}

resource "aws_vpc" "db" {
  cidr_block           = var.vpcCIDRblock
  instance_tenancy     = var.instanceTenancy

  tags = {
    Name = "DbServer"
  }
}

resource "aws_subnet" "db_subnet" {
  vpc_id                  = aws_vpc.db.id
  cidr_block              = var.subnetCIDRblock
  map_public_ip_on_launch = var.mapPublicIP
  availability_zone       = var.availabilityZone
  tags = {
    Name = "My VPC Subnet"
  }
}

resource "aws_security_group" "db_security_group" {
  vpc_id       = aws_vpc.db.id
  name         = "My VPC Security Group"
  description  = "My VPC Security Group"

  # allow ingress of port 22
  ingress {
    cidr_blocks = var.ingressCIDRblock
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  # allow ingress of port 22
  ingress {
    cidr_blocks = var.ingressCIDRblock
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
  }

  # allow egress of all ports
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "My VPC Security Group"
    Description = "My VPC Security Group"
  }
}

resource "aws_internet_gateway" "My_VPC_GW" {
  vpc_id = aws_vpc.db.id
  tags = {
    Name = "My VPC Internet Gateway"
  }
}
resource "aws_route_table" "My_VPC_route_table" {
  vpc_id = aws_vpc.db.id
  tags = {
    Name = "My VPC Route Table"
  }
}
resource "aws_route" "My_VPC_internet_access" {
  route_table_id         = aws_route_table.My_VPC_route_table.id
  destination_cidr_block = var.destinationCIDRblock
  gateway_id             = aws_internet_gateway.My_VPC_GW.id
}

resource "aws_route_table_association" "My_VPC_association" {
  subnet_id      = aws_subnet.db_subnet.id
  route_table_id = aws_route_table.My_VPC_route_table.id
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}

resource "aws_instance" "db" {
  ami = "ami-0e610eb0d0a0c813a"
  instance_type = "t3.micro"

  subnet_id              = aws_subnet.db_subnet.id
  vpc_security_group_ids = [aws_security_group.db_security_group.id]

  key_name = "deployer-key"

  provisioner "file" {
    source      = "script.sh"
    destination = "/tmp/script.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/script.sh",
      "/tmp/script.sh args",
    ]
  }

  connection {
    type     = "ssh"
    user     = "ubuntu"
    private_key = "${file("~/.ssh/id_rsa")}"
    host     = self.public_ip
  }
}