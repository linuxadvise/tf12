data "aws_caller_identity" "current" {
}

data "aws_region" "current" {
}

data "aws_ami" "ecs_ami" {
  most_recent = true

  filter {
    name = "name"

    values = [
      var.ami_search_name,
    ]
  }

  owners = var.ami_account_owner_ids
}

resource "aws_kms_grant" "asg_kms_grant" {
  count             = var.cmk_arn == "" ? 0 : 1
  name              = "${var.name}-asg_kms_grant"
  grantee_principal = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
  key_id            = var.cmk_arn

  operations = [
    "Decrypt",
    "ReEncryptFrom",
    "ReEncryptTo",
    "CreateGrant",
  ]
}

data "aws_iam_policy_document" "ecs_policy_document" {
  # basic requirements of the ECS agent
  statement {
    actions = [
      "ecs:DiscoverPollEndpoint",
      "ecs:Poll",
      "ecs:Submit",
    ]

    resources = [
      "*",
    ]
  }

  # ECS CloudWatch metrics
  statement {
    actions = [
      "ecs:StartTelemetrySession",
    ]

    resources = [
      "*",
    ]
  }

  # CloudWatch logs
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]

    resources = [
      "arn:aws:logs:*:*:*",
    ]
  }

  statement {
    actions = [
      "ecs:*",
    ]

    resources = concat(["arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.name}*,"],
      formatlist("arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:task-definition/%s",
        compact(aws_ecs_task_definition.datadog_task.*.family),
      ),
    )

  }

  statement {
    actions = [
      "ec2:DescribeInstances",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetAuthorizationToken",
    ]

    resources = [
      "*",
    ]
  }
}

data "aws_iam_policy_document" "lambda_policy_document" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]

    resources = [
      "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:*",
    ]
  }
}

data "aws_iam_policy_document" "xray_policy_document" {
  statement {
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries",
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_role" "ecs_iam_role" {
  name = "${var.name}-ecs"

  tags = merge(
    {
      "Name" = "ecs_iam_role"
    },
    var.additional_map_tags,
  )

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "ec2.amazonaws.com",
          "ecs.amazonaws.com",
          "ecs-tasks.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_role_policy" "ecs_role_policy" {
  name   = "${var.name}-ecs"
  role   = aws_iam_role.ecs_iam_role.id
  policy = data.aws_iam_policy_document.ecs_policy_document.json
}

resource "aws_iam_role_policy" "xray_role_policy" {
  count = var.enable_xray == 1 ? 1 : 0

  name   = "${var.name}-ecs-xray-policy"
  role   = aws_iam_role.ecs_iam_role.id
  policy = data.aws_iam_policy_document.xray_policy_document.json
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = var.name
  role = aws_iam_role.ecs_iam_role.name
}

resource "aws_security_group" "instance_sg" {
  description = "Access between application instances"
  vpc_id      = var.vpc_id
  name_prefix = "${var.name}-instance-"

  ingress {
    protocol  = "-1"
    from_port = 0
    to_port   = 0
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      "Name"        = "${var.name}-instance"
      "environment" = var.name
    },
    var.additional_map_tags,
  )
}

resource "aws_iam_role" "iam_for_lambda" {
  count = min(length(split("", var.sumologic_endpoint_url)), 1)

  name = "${var.name}-lambda"

  tags = merge(
    {
      "Name" = "ecs_iam_role"
    },
    var.additional_map_tags,
  )

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_role_policy" "lambda_role_policy" {
  count = min(length(split("", var.sumologic_endpoint_url)), 1)

  name   = "${var.name}-lambda-policy"
  role   = aws_iam_role.iam_for_lambda[0].id
  policy = data.aws_iam_policy_document.lambda_policy_document.json
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.terraform/archive_files/cloudwatchlogs_lambda.zip"
}

resource "aws_lambda_function" "sumo-cloudwatch" {
  count = min(length(split("", var.sumologic_endpoint_url)), 1)

  filename         = "${path.module}/.terraform/archive_files/cloudwatchlogs_lambda.zip"
  function_name    = "${var.name}-sumo-cloudwatch"
  role             = aws_iam_role.iam_for_lambda[0].arn
  handler          = "cloudwatchlogs_lambda.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "nodejs10.x"

  depends_on = [data.archive_file.lambda_zip]

  environment {
    variables = {
      SUMO_ENDPOINT = var.sumologic_endpoint_url
    }
  }

  tags = merge(
    {
      "Name" = "sumo-cloudwatch"
    },
    var.additional_map_tags,
  )
}

resource "aws_lambda_permission" "allow_cloudwatch_logs" {
  count = min(length(split("", var.sumologic_endpoint_url)), 1)

  statement_id  = "${var.name}CloudwatchLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sumo-cloudwatch[0].function_name
  principal     = "logs.${data.aws_region.current.name}.amazonaws.com"
}

# Cloudwatch log groups may be automatically created by the resources that write to them.
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "${var.name}-ecs"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = var.additional_map_tags
}

resource "aws_cloudwatch_log_group" "container" {
  name              = "${var.name}-container"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = var.additional_map_tags
}

# ECS system logs
resource "aws_cloudwatch_log_subscription_filter" "cloudwatch-filter-ecs" {
  count           = min(length(split("", var.sumologic_endpoint_url)), 1)
  name            = "${var.name}-ecs"
  log_group_name  = "${var.name}-ecs"
  filter_pattern  = ""
  destination_arn = aws_lambda_function.sumo-cloudwatch[0].arn

  depends_on = [
    aws_cloudwatch_log_group.ecs,
    aws_cloudwatch_log_group.container,
  ]
}

# Container logs
resource "aws_cloudwatch_log_subscription_filter" "cloudwatch-filter-container" {
  count           = length(split("", var.sumologic_endpoint_url)) > 0 ? length(var.sumologic_filters) : 0
  name            = "${var.name}-container"
  log_group_name  = "${var.name}-container"
  filter_pattern  = element(var.sumologic_filters, count.index)
  destination_arn = aws_lambda_function.sumo-cloudwatch[0].arn

  depends_on = [
    aws_cloudwatch_log_group.ecs,
    aws_cloudwatch_log_group.container,
  ]
}

data "template_file" "datadog_task_json" {
  template = file("${path.module}/dd-agent-ecs.json")

  vars = {
    api_key                = var.datadog_api_key
    docker_image           = var.datadog_docker_image
    name                   = var.name
    aws_region             = data.aws_region.current.name
    datadog_labels_as_tags = var.datadog_labels_as_tags
  }
}

resource "aws_ecs_task_definition" "datadog_task" {
  count = min(length(split("", var.datadog_api_key)), 1)

  family                = "${var.name}-dd-agent"
  container_definitions = data.template_file.datadog_task_json.rendered

  volume {
    name      = "docker_sock"
    host_path = "/var/run/docker.sock"
  }

  volume {
    name      = "proc"
    host_path = "/proc/"
  }

  volume {
    name      = "cgroup"
    host_path = "/sys/fs/cgroup/"
  }

  tags = merge(
    {
      "Name" = "datadog_task"
    },
    var.additional_map_tags,
  )
}

resource "aws_ecs_service" "datadog_service" {
  count               = min(length(split("", var.datadog_api_key)), 1)
  name                = "${var.name}-dd-agent"
  cluster             = aws_ecs_cluster.main.id
  task_definition     = aws_ecs_task_definition.datadog_task[0].arn
  scheduling_strategy = "DAEMON"
}

data "template_file" "cloud_config" {
  template = file("${path.module}/cloud-config.yaml")

  vars = {
    tf_cluster_name = var.name
    tf_enable_xray  = var.enable_xray
    #The spaces are important because these lines go into a yaml file
    tf_custom_userdata = join("\n        ", var.ecs_userdata_configuration)
  }
}

resource "aws_launch_configuration" "amazon_linux_2" {
  name_prefix          = var.name
  image_id             = data.aws_ami.ecs_ami.id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.name
  key_name             = var.launch_config_key_name
  security_groups = concat(
    var.extra_security_groups,
    [aws_security_group.instance_sg.id],
  )
  user_data = data.template_file.cloud_config.rendered

  root_block_device {
    volume_type = "gp2"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "amazon_linux_2_secondary" {
  count                = var.enable_secondary_asg == 1 ? 1 : 0
  name_prefix          = "${var.name}_secondary"
  image_id             = data.aws_ami.ecs_ami.id
  instance_type        = var.secondary_asg_options["instance_type"]
  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.name
  key_name             = var.launch_config_key_name
  security_groups = concat(
    var.extra_security_groups,
    [aws_security_group.instance_sg.id],
  )
  user_data = data.template_file.cloud_config.rendered

  root_block_device {
    volume_type = "gp2"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "ecs_asg" {
  name             = var.name
  max_size         = var.max_size
  min_size         = var.min_size
  desired_capacity = max(min(var.desired_capacity, var.max_size), var.min_size)

  vpc_zone_identifier = var.vpc_zone_identifier

  health_check_grace_period = var.health_check_grace_period
  health_check_type         = var.health_check_type
  force_delete              = false
  termination_policies      = var.termination_policies
  wait_for_capacity_timeout = "10m"
  protect_from_scale_in     = var.scale_in_protection

  enabled_metrics = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]

  launch_configuration = aws_launch_configuration.amazon_linux_2.name

  tags = concat(
    [
      {
        "key"                 = "Name"
        "value"               = var.name
        "propagate_at_launch" = true
      },
      {
        "key"                 = "environment"
        "value"               = var.name
        "propagate_at_launch" = true
      },
    ],
    var.extra_tags,
  )


  depends_on = [aws_kms_grant.asg_kms_grant]
}

resource "aws_autoscaling_group" "ecs_asg_secondary" {
  count            = var.enable_secondary_asg == 1 ? 1 : 0
  name             = "${var.name}_secondary"
  max_size         = var.secondary_asg_options["max_size"]
  min_size         = var.secondary_asg_options["min_size"]
  desired_capacity = var.secondary_asg_options["min_size"]

  vpc_zone_identifier = var.vpc_zone_identifier

  health_check_grace_period = var.health_check_grace_period
  health_check_type         = var.health_check_type
  force_delete              = false
  termination_policies      = var.termination_policies
  wait_for_capacity_timeout = "10m"
  protect_from_scale_in     = var.scale_in_protection

  enabled_metrics = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]

  launch_configuration = aws_launch_configuration.amazon_linux_2_secondary[0].name
  
  tags = concat(
    [
      {
        "key"                 = "Name"
        "value"               = var.name
        "propagate_at_launch" = true
      },
      {
        "key"                 = "environment"
        "value"               = var.name
        "propagate_at_launch" = true
      },
    ],
    var.extra_tags,
  )

  depends_on = [
    aws_kms_grant.asg_kms_grant,
    aws_autoscaling_group.ecs_asg,
  ]
}

resource "aws_ecs_cluster" "main" {
  name = var.name

  tags = merge(
    {
      "Name" = var.name
    },
    var.additional_map_tags,
  )
}
