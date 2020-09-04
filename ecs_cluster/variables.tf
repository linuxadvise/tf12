## REQUIRED
variable "name" {
  description = "The unique name for this ECS cluster"
}

## REQUIRED
variable "vpc_id" {
  description = "The ID of the VPC for this cluster"
}

variable "extra_security_groups" {
  default     = []
  description = "List of external security group IDs to apply (if any) to instances in this cluster"
}

## REQUIRED
variable "vpc_zone_identifier" {
  type        = list(string)
  description = "List of subnet IDs to launch resources in"
}

## REQUIRED
variable "ami_search_name" {
  type        = string
  description = "Use the latest AMI whose Name matches this string"
}

variable "ami_account_owner_ids" {
  type        = list(string)
  description = "Accounts to search for AMIs"
  default     = ["self", "081480024710"]
}

variable "datadog_api_key" {
  default     = ""
  description = "Datadog API key.  Will skip datadog integration if left blank"
}

variable "datadog_docker_image" {
  default     = "datadog/docker-dd-agent:latest"
  description = "Datadog Docker image"
}

variable "datadog_labels_as_tags" {
  default     = ""
  description = "Comma-separated container label names to be used for tagging metrics - see [this link](https://github.com/DataDog/integrations-core/blob/f9efbe00b745491b23927760f13afed57b0ead87/docker_daemon/conf.yaml.example#L187-L194) for details."
}

variable "sumologic_endpoint_url" {
  default     = ""
  description = "Sumo Logic hosted collector HTTP source URL.  Will skip Sumo Logic integration if left blank"
}

# A simple example to exclude any log with INFO in it:
# sumologic_filters      = [ "-INFO" ]
variable "sumologic_filters" {
  default     = [""]
  description = "CloudWatch log filters to select what will be sent to SumoLogic.  Defaults to all logs.  [Syntax information](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html)"
}

variable "cloudwatch_log_retention_days" {
  default     = 7
  description = "Number of days to retain logs in CloudWatch Logs.  0 for indefinite.  Does not affect Sumo Logic retention."
}

variable "instance_type" {
  default     = "t2.xlarge"
  description = "Instance type for the cluster"
}

variable "root_volume_size" {
  default     = "100"
  description = "Size of root volume for each instance (GB)"
}

variable "min_size" {
  default     = 1
  description = "ASG min_size"
}

variable "max_size" {
  default     = 1
  description = "ASG max_size"
}

variable "desired_capacity" {
  default     = 1
  description = "ASG desired_capacity"
}

variable "scale_in_protection" {
  default     = false
  description = "Whether to set ECS container instances for scale-in termination protection"
}

variable "health_check_grace_period" {
  default     = 300
  description = "Time (in seconds) after instance comes into service before checking health"
}

variable "health_check_type" {
  default     = "EC2"
  description = "Type of ASG health check.  'EC2' or 'ELB'"
}

variable "termination_policies" {
  type        = list(string)
  default     = ["OldestInstance"]
  description = "ASG termination policies.  Allowed values: `OldestInstance`, `NewestInstance`, `OldestLaunchConfiguration`, `ClosestToNextInstanceHour`, `Default`"
}

variable "launch_config_key_name" {
  default     = ""
  description = "EC2 SSH keypair name to apply to all container instances.  Defaults to none."
}

variable "ecs_userdata_configuration" {
  description = "Individual commands that will run at launch for each container instance"

  default = [
    "sysctl -w vm.max_map_count=262144",
  ]
}

variable "extra_tags" {
  description = "Additional tags to be propagated to ec2 instances created by autoscaling group"
  default     = []
}

variable "cmk_arn" {
  description = "Grant access to the KMS CMK specified by this ARN. Required if the source AMI is encrypted."
  default     = ""
}

variable "additional_map_tags" {
  description = "additional custom tags for resources"
  type        = map(string)
  default     = {}
}

variable "enable_xray" {
  default = false
}

variable "enable_secondary_asg" {
  description = "HDH has as special use case where it requires 2 autoscaling groups; one with M5 insances(primary) and the other with C5 instances(secondary)"
  default     = false
}

variable "secondary_asg_options" {
  type        = map(string)
  description = "Options for the secondary ASG (See enable_secondary_asg)"

  default = {
    "instance_type" = "c5d.xlarge"
    "max_size"      = 15
    "min_size"      = 9
  }
}

