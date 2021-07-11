resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = merge(var.all_tags, { Name = "${var.all_tags["Environment"]} main-VPC" })
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = merge(var.all_tags, { Name = "${var.all_tags["Environment"]} Subnet-a" })
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = merge(var.all_tags, { Name = "${var.all_tags["Environment"]} Subnet-b" })
}

resource "aws_internet_gateway" "vpc_ig" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.all_tags, { Name = "${var.all_tags["Environment"]} Internet Gateway" })
}

resource "aws_route_table" "vpc_route" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc_ig.id
  }
  tags = merge(var.all_tags, { Name = "${var.all_tags["Environment"]} Route Table" })
}

resource "aws_route_table_association" "subnet_a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.vpc_route.id
}

resource "aws_route_table_association" "subnet_b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.vpc_route.id
}
