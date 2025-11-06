######## ECS 
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.env}-${var.cluster_name}-${var.cell_name}"
}

resource "aws_ecs_service" "my_app_service" {
  name            = "${var.env}-${var.cluster_name}-service-${var.cell_name}"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.my_app_task.arn
  launch_type     = "${var.ecs_type}"
  desired_count   = var.desired_containers
  depends_on = [
    aws_iam_role_policy_attachment.ecs_execution_role_policy,
    aws_iam_role_policy_attachment.ecs_execution_ecr_vpc_attach,
    aws_iam_policy_attachment.ecs_task_s3_attach,
    aws_lb_listener.ecs_alb_listener
  ]
  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg.arn
    container_name   = "${var.image_name}"
    container_port   = var.container_port
  }
  network_configuration {
    subnets          = var.service_subnets
    security_groups  = var.service_security_groups
    assign_public_ip = var.public_ip
  }
  
}

# ECS Task Definition Configuration
data "aws_caller_identity" "current" {} # to get your Account ID 
resource "aws_ecs_task_definition" "my_app_task" {
  family                   = "${var.env}-${var.cluster_name}_task_${var.cell_name}"
  requires_compatibilities = ["${var.ecs_type}"]
  network_mode             = var.network_mode
  cpu                      = var.cpu_size
  memory                   = var.memory_size
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([
    {
      name      = "${var.image_name}"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.cluster_region}.amazonaws.com/${var.repo_name}:latest"
      essential = true
        environment = [
        {
          name  = "POSTGRES_DB"
          value = var.db_name
        },
        {
          name  = "POSTGRES_USER"
          value = var.db_username
        },
        {
          name  = "POSTGRES_HOST"
          value = var.db_endpoint
        },
        {
          name  = "POSTGRES_PORT"
          value = tostring(var.db_port)
        },
        {
          name      = "POSTGRES_PASSWORD"
          value = var.db_password
        }
      ]
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.host_port
        }
      ]
      logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group = "/ecs/${var.image_name}"
            awslogs-region        = "${var.cluster_region}"
            awslogs-stream-prefix = "ecs"
          }
       }
    }
  ])
  
}


# IAM Role Configuration
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.env}-ecs-task-execution-role-${var.cell_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.env}-ecs-task-execution-role-${var.env}"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "ecs_execution_ecr_vpc_policy" {
  name = "${var.env}-ecs-execution-ecr-vpc-policy-${var.cell_name}"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "secretsmanager:GetSecretValue",
          "kms:Decrypt",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_ecr_vpc_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_execution_ecr_vpc_policy.arn
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.env}-ecs-task-role-${var.cell_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.env}-ecs-task-role"
  }
}

resource "aws_iam_policy" "ecs_task_s3_policy" {
  name        = "${var.env}-ecs-task-s3-policy-${var.cell_name}"
  description = "Policy for ECS tasks to access S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "ecs_task_s3_attach" {
  name       = "${var.env}-ecs-task-s3-attach-${var.cell_name}"
  roles      = [aws_iam_role.ecs_task_role.name]
  policy_arn = aws_iam_policy.ecs_task_s3_policy.arn
}

# ALB 
resource "aws_lb" "ecs_alb" {
  name                       = "ecs-alb-${var.cell_name}"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = var.alb_security_groups
  subnets                    = var.alb_subnets
  enable_deletion_protection = false

  tags = {
    Name = "ecs-alb"
  }
}

resource "aws_lb_target_group" "ecs_tg" {
  name        = "ecs-target-group-${var.cell_name}"
  port        = var.container_port # default port to the audience
  protocol    = "HTTP"
  target_type = "${var.alb_target_type}"
  vpc_id      = var.vpc_id

  health_check {
    path     = "/"
    protocol = "HTTP"
    port     = var.container_port
  }
}

resource "aws_lb_listener" "ecs_alb_listener" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = var.container_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }
}
