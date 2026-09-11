resource "aws_db_subnet_group" "capstone_db_subnet_group" {
  name       = "capstone-db-subnet-group"
  subnet_ids = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
}

resource "aws_security_group" "capstone_db_sg" {
  name   = "capstone-db-sg"
  vpc_id = aws_vpc.capstone_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "capstone_db" {
  identifier             = "capstone-db"
  instance_class         = "db.t3.micro"
  engine                 = "mysql"
  allocated_storage      = 20
  username               = "admin"
  password               = "CapstoneDB123!"
  db_subnet_group_name   = aws_db_subnet_group.capstone_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.capstone_db_sg.id]
  skip_final_snapshot    = true
}
