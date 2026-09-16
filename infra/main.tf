# ============================================================
# AWS PROVIDER
# ============================================================

provider "aws" {
  region = "us-east-1"
}

# ============================================================
# AVAILABILITY ZONES
# ============================================================

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

# ============================================================
# VPC
# ============================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "nginx-ecs-vpc"
  }
}

# ============================================================
# INTERNET GATEWAY
# ============================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "nginx-ecs-igw"
  }
}

# ============================================================
# PUBLIC SUBNETS
# ============================================================

resource "aws_subnet" "public" {
  count = 2

  vpc_id = aws_vpc.main.id

  availability_zone = local.azs[count.index]

  cidr_block = cidrsubnet(
    aws_vpc.main.cidr_block,
    8,
    count.index
  )

  map_public_ip_on_launch = true

  tags = {
    Name = "nginx-public-${count.index + 1}"
    Tier = "public"
  }
}

# ============================================================
# PRIVATE SUBNETS
# ============================================================

resource "aws_subnet" "private" {
  count = 2

  vpc_id = aws_vpc.main.id

  availability_zone = local.azs[count.index]

  cidr_block = cidrsubnet(
    aws_vpc.main.cidr_block,
    8,
    count.index + 10
  )

  map_public_ip_on_launch = false

  tags = {
    Name = "nginx-private-${count.index + 1}"
    Tier = "private"
  }
}

# ============================================================
# PUBLIC ROUTE TABLE
# ============================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "nginx-public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id = aws_subnet.public[count.index].id

  route_table_id = aws_route_table.public.id
}

# ============================================================
# NAT GATEWAY ELASTIC IP
# ============================================================

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "nginx-nat-eip"
  }

  depends_on = [
    aws_internet_gateway.main
  ]
}

# ============================================================
# NAT GATEWAY
# ============================================================

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id

  subnet_id = aws_subnet.public[0].id

  tags = {
    Name = "nginx-nat-gateway"
  }

  depends_on = [
    aws_internet_gateway.main
  ]
}

# ============================================================
# PRIVATE ROUTE TABLE
# ============================================================

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "nginx-private-rt"
  }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id = aws_subnet.private[count.index].id

  route_table_id = aws_route_table.private.id
}

# ============================================================
# ALB SECURITY GROUP
# ============================================================

resource "aws_security_group" "alb" {
  name        = "nginx-alb-sg"
  description = "Allow HTTP and HTTPS traffic to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"

    from_port = 80
    to_port   = 80

    protocol = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  ingress {
    description = "HTTPS from Internet"

    from_port = 443
    to_port   = 443

    protocol = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  egress {
    description = "Allow outbound traffic"

    from_port = 0
    to_port   = 0

    protocol = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = {
    Name = "nginx-alb-sg"
  }
}

# ============================================================
# ECS SECURITY GROUP
# ============================================================

resource "aws_security_group" "ecs" {
  name        = "nginx-ecs-sg"
  description = "Allow traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from ALB"

    from_port = 80
    to_port   = 80

    protocol = "tcp"

    security_groups = [
      aws_security_group.alb.id
    ]
  }

  egress {
    description = "Allow outbound traffic"

    from_port = 0
    to_port   = 0

    protocol = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = {
    Name = "nginx-ecs-sg"
  }
}

# ============================================================
# ECR REPOSITORY
# ============================================================

resource "aws_ecr_repository" "nginx" {
  name                 = "nginx-ecs-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "nginx-ecs-app"
  }
}

# ============================================================
# ECR LIFECYCLE POLICY
# Keep only the latest 10 images
# ============================================================

resource "aws_ecr_lifecycle_policy" "nginx" {
  repository = aws_ecr_repository.nginx.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1

        description = "Keep only the latest 10 images"

        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }

        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ============================================================
# APPLICATION LOAD BALANCER
# ============================================================

resource "aws_lb" "main" {
  name               = "nginx-ecs-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = aws_subnet.public[*].id

  tags = {
    Name = "nginx-ecs-alb"
  }
}

# ============================================================
# TARGET GROUP
# ============================================================

resource "aws_lb_target_group" "app" {
  name        = "nginx-ecs-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"

  vpc_id = aws_vpc.main.id

  health_check {
    enabled = true

    protocol = "HTTP"

    path = "/"

    port = "traffic-port"

    healthy_threshold = 2

    unhealthy_threshold = 3

    timeout = 5

    interval = 30

    matcher = "200-399"
  }

  tags = {
    Name = "nginx-ecs-tg"
  }
}

# ============================================================
# HTTP LISTENER
# Redirect HTTP → HTTPS
# ============================================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn

  port = 80

  protocol = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port = "443"

      protocol = "HTTPS"

      status_code = "HTTP_301"
    }
  }
}

# ============================================================
# HTTPS LISTENER
# ============================================================

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn

  port = 443

  protocol = "HTTPS"

  ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  certificate_arn = "arn:aws:acm:us-east-1:288761730265:certificate/4892e0dc-aa97-4019-bb23-793cb19fdcdb"

  default_action {
    type = "forward"

    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ============================================================
# ECS CLUSTER
# ============================================================

resource "aws_ecs_cluster" "main" {
  name = "nginx-cluster"

  tags = {
    Name = "nginx-cluster"
  }
}

# ============================================================
# CLOUDWATCH LOG GROUP
# ============================================================

resource "aws_cloudwatch_log_group" "ecs" {
  name = "/ecs/nginx-app"

  retention_in_days = 7

  tags = {
    Name = "nginx-app-logs"
  }
}

# ============================================================
# ECS TASK EXECUTION ROLE
# ============================================================

resource "aws_iam_role" "ecs_execution_role" {
  name = "nginx-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "nginx-ecs-execution-role"
  }
}

# ============================================================
# ECS EXECUTION ROLE POLICY
# ============================================================

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role = aws_iam_role.ecs_execution_role.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ============================================================
# ECS TASK DEFINITION
# ============================================================

resource "aws_ecs_task_definition" "nginx" {
  family = "nginx-app"

  network_mode = "awsvpc"

  requires_compatibilities = [
    "FARGATE"
  ]

  cpu = "256"

  memory = "512"

  execution_role_arn = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name = "nginx"

      # GitHub Actions will push this image to ECR
      image = "${aws_ecr_repository.nginx.repository_url}:latest"

      essential = true

      portMappings = [
        {
          containerPort = 80

          hostPort = 80

          protocol = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group" = aws_cloudwatch_log_group.ecs.name

          "awslogs-region" = "us-east-1"

          "awslogs-stream-prefix" = "nginx"
        }
      }
    }
  ])

  tags = {
    Name = "nginx-task"
  }
}

# ============================================================
# ECS SERVICE
# ============================================================

resource "aws_ecs_service" "main" {
  name = "nginx-service"

  cluster = aws_ecs_cluster.main.id

  task_definition = aws_ecs_task_definition.nginx.arn

  desired_count = 2

  launch_type = "FARGATE"

  network_configuration {
    subnets = aws_subnet.private[*].id

    security_groups = [
      aws_security_group.ecs.id
    ]

    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn

    container_name = "nginx"

    container_port = 80
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener.https
  ]

  lifecycle {
    ignore_changes = [
      desired_count
    ]
  }

  tags = {
    Name = "nginx-service"
  }
}

# ============================================================
# ECS AUTO SCALING TARGET
# MIN = 2
# MAX = 6
# ============================================================

resource "aws_appautoscaling_target" "ecs" {
  min_capacity = 2

  max_capacity = 6

  resource_id = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"

  scalable_dimension = "ecs:service:DesiredCount"

  service_namespace = "ecs"
}

# ============================================================
# ECS CPU AUTO SCALING
# ============================================================

resource "aws_appautoscaling_policy" "ecs_cpu" {
  name = "nginx-cpu-scaling"

  policy_type = "TargetTrackingScaling"

  resource_id = aws_appautoscaling_target.ecs.resource_id

  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension

  service_namespace = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = 75

    scale_in_cooldown = 300

    scale_out_cooldown = 60
  }
}

# ============================================================
# OUTPUTS
# ============================================================

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"

  value = aws_lb.main.dns_name
}

output "alb_url" {
  description = "HTTPS URL for the Application Load Balancer"

  value = "https://${aws_lb.main.dns_name}"
}

output "ecs_cluster_name" {
  description = "ECS cluster name"

  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name"

  value = aws_ecs_service.main.name
}

output "ecr_repository_url" {
  description = "ECR repository URL"
}
