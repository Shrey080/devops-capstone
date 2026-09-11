resource "aws_elasticache_subnet_group" "capstone_redis_subnet_group" {
  name       = "capstone-redis-subnet-group"
  subnet_ids = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
}

resource "aws_security_group" "capstone_redis_sg" {
  name   = "capstone-redis-sg"
  vpc_id = aws_vpc.capstone_vpc.id

  ingress {
    from_port   = 6379
    to_port     = 6379
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

resource "aws_elasticache_cluster" "capstone_redis" {
  cluster_id           = "capstone-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.capstone_redis_subnet_group.name
  security_group_ids   = [aws_security_group.capstone_redis_sg.id]
}
