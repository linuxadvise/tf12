provider "aws" {
  region  = "us-west-2"
  profile = "sandbox"
}

variable "name" {
  default = "ecs-test"
}

variable "datadog_api_key" {
  default = ""
}

variable "sumologic_endpoint_url" {
  default = ""
}

variable "ami_search_name" {
  type = string
}

variable "keypair_name" {
  type    = string
  default = ""
}

data "aws_vpc" "main" {
  tags = {
    Name = "main"
  }
}

data "aws_subnet_ids" "private" {
  vpc_id = data.aws_vpc.main.id

  tags = {
    type = "private"
  }
}

resource "aws_security_group" "ssh" {
  description = "Access to/from application instances"
  vpc_id      = data.aws_vpc.main.id
  name_prefix = "${var.name}-ssh-"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["10.0.0.0/8"]
  }

  tags = {
    Name        = "${var.name}-instance"
    environment = var.name
  }
}

module "ecs_cluster" {
  source           = "../.."
  name             = var.name
  min_size         = 2
  max_size         = 2
  desired_capacity = 2

  ami_search_name = var.ami_search_name

  launch_config_key_name = var.keypair_name

  root_volume_size = "50"

  sumologic_endpoint_url = var.sumologic_endpoint_url

  vpc_id              = data.aws_vpc.main.id
  vpc_zone_identifier = data.aws_subnet_ids.private.ids

  extra_security_groups = [aws_security_group.ssh.id]

  datadog_api_key = var.datadog_api_key
}

# Launch one test container via conventional means
resource "aws_ecs_task_definition" "servicebox" {
  family       = "${var.name}-servicebox"
  network_mode = "bridge"

  container_definitions = <<EOF
[
  {
    "image": "ubuntu",
    "name": "servicebox",
    "memory": 1024,
    "command": ["bash", "-c", "touch /tmp/testlog && tail -F /tmp/testlog"],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${var.name}-container",
        "awslogs-region": "us-west-2",
        "awslogs-stream-prefix": "${var.name}-servicebox"
      }
    }
  }
]
EOF

}

resource "aws_ecs_service" "servicebox" {
  name            = "servicebox"
  cluster         = module.ecs_cluster.ecs_cluster_arn
  task_definition = aws_ecs_task_definition.servicebox.arn
  desired_count   = 1
}
