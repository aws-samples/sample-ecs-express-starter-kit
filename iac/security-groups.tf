resource "aws_vpc" "express-mode" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    local.common_tags,
    {
      Name = "express-mode-main-vpc"
    }
  )
}

resource "aws_subnet" "private" {
  count                   = 2
  vpc_id                  = aws_vpc.express-mode.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = merge(
    local.common_tags,
    {
      Name = "express-mode-private-subnet-${count.index}"
    }
  )
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.express-mode.id
  cidr_block              = "10.0.${count.index + 10}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name = "express-mode-public-subnet-${count.index}"
    }
  )
}

data "aws_availability_zones" "available" {}

resource "aws_security_group" "ecs" {
  name   = "ecs-express-sg"
  vpc_id = aws_vpc.express-mode.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_security_group" "db" {
  name        = "aurora-sg"
  description = "Allow ECS to access Aurora"
  vpc_id      = aws_vpc.express-mode.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  # egress {
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  tags = local.common_tags
}

#### If we need ECS in private subnets 
# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.express-mode.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = local.common_tags
}

# Secrets Manager VPC Endpoint
# resource "aws_vpc_endpoint" "secretsmanager" {
#   vpc_id              = aws_vpc.express-mode.id
#   service_name        = "com.amazonaws.${var.region}.secretsmanager"
#   vpc_endpoint_type   = "Interface"
#   # subnet_ids          = aws_subnet.private[*].id
#   subnet_ids          = aws_subnet.public[*].id
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true

#   tags = local.common_tags
# }

# # CloudWatch Logs VPC Endpoint
# resource "aws_vpc_endpoint" "logs" {
#   vpc_id              = aws_vpc.express-mode.id
#   service_name        = "com.amazonaws.${var.region}.logs"
#   vpc_endpoint_type   = "Interface"
#   # subnet_ids          = aws_subnet.private[*].id
#   subnet_ids          = aws_subnet.public[*].id
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true

#   tags = local.common_tags
# }



#### on-demand
# resource "aws_vpc_endpoint" "ecr_api" {
#   vpc_id              = aws_vpc.express-mode.id
#   service_name        = "com.amazonaws.${var.region}.ecr.api"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = aws_subnet.private[*].id
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true

#   tags = local.common_tags
# }

# resource "aws_vpc_endpoint" "ecr_dkr" {
#   vpc_id              = aws_vpc.express-mode.id
#   service_name        = "com.amazonaws.${var.region}.ecr.dkr"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = aws_subnet.private[*].id
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true

#   tags = local.common_tags
# }

# resource "aws_vpc_endpoint" "s3" {
#   vpc_id            = aws_vpc.express-mode.id
#   service_name      = "com.amazonaws.${var.region}.s3"
#   vpc_endpoint_type = "Gateway"
#   route_table_ids   = [aws_route_table.private.id]

#   tags = local.common_tags
# }


# Nat Gateway
# resource "aws_subnet" "public" {
#   count                   = 2
#   vpc_id                  = aws_vpc.express-mode.id
#   cidr_block              = "10.0.${count.index + 10}.0/24"
#   availability_zone       = data.aws_availability_zones.available.names[count.index]
#   map_public_ip_on_launch = true

#   tags = merge(
#     local.common_tags,
#     {
#       Name = "express-mode-public-subnet-${count.index}"
#     }
#   )
# }

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.express-mode.id
  tags   = local.common_tags
}

# resource "aws_eip" "nat" {
#   domain = "vpc"
#   tags   = local.common_tags
# }

# resource "aws_nat_gateway" "main" {
#   allocation_id = aws_eip.nat.id
#   subnet_id     = aws_subnet.public[0].id
#   tags          = local.common_tags
#   depends_on    = [aws_internet_gateway.main]
# }

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.express-mode.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = local.common_tags
}

# resource "aws_route_table" "private" {
#   vpc_id = aws_vpc.express-mode.id

#   route {
#     cidr_block     = "0.0.0.0/0"
#     nat_gateway_id = aws_nat_gateway.main.id
#   }

#   tags = local.common_tags
# }

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# resource "aws_route_table_association" "private" {
#   count          = 2
#   subnet_id      = aws_subnet.private[count.index].id
#   route_table_id = aws_route_table.private.id
# }