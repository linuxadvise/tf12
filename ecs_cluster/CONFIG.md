
[Back to intro](README.md)

# Configuration

For a basic starting-point configuration, see the [simple example](examples/simple.tf)


## Instance Parameters
`ami_search_name` is set to the value of the `Name` tag in the AMI to use.  Whenever ePHI will be present, use the
NextGen-supplied encrypted AMI

`cmk_arn`, when specified, creates a grant to allow the cluster access to the KMS Customer-Managed Key being used by the AMI
above.

`ecs_userdata_configuration` is a list of shell commands to be added into the first-time boot configuration of each instance in
the cluster. Please pay attention to leading/trailing whitespaces as the contents of this list will be placed into a yaml file.

`extra_security_groups` specifies the IDs of externally-defined security groups that will apply to all instances in the
cluster.  This is how you open uo outside traffic into the cluster.

`extra_tags` specifies tags that will be added to each instance in the cluster.  Example:
```
    extra_tags = [
      {
        key = "someKey"
        value = "someValue"
        propagate_at_launch = true
      }
    ]
```


## Logging and Instrumentation

Logs are sent from the containers to CloudWatch Logs via the `awslogs` log driver.  From CloudWatch Logs, it is channeled to Sumo Logic via a lambda function based on [this code](https://github.com/SumoLogic/sumologic-aws-lambda/tree/master/cloudwatchlogs)

To integrate with Sumo Logic, create a hosted collector HTTP endpoint and set the variable `sumologic_endpoint_url`
to the endpoint's URL.  Use the `sumologic_filters` variable to adjust which logs will be sent.

For instructions on creating a hosted endpoint, see
https://help.sumologic.com/Send-Data/Sources/02Sources-for-Hosted-Collectors/HTTP-Source

Note that the endpoint URL contains an authentication key, so it should not be shared with the public.

To configure a container to send its logs to Sumo, add a block like the following to its ECS task definition, replacing the variables in curly braces as appropriate:
```
      "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
              "awslogs-group": "{ECS_STACK_NAME_GOES_HERE}-container",
              "awslogs-region": "{REGION_NAME_GOES_HERE}",
              "awslogs-stream-prefix": "{CONTAINER_NAME_GOES_HERE}"
          }
      }
```

As Sumo Logic charges increase with the volume of logs sent, be aware of how many logs your application is sending.  Use `sumologic_filters` to keep overly-verbose logs from being sent -- they will still be available in CloudWatch Logs within the retention set by `cloudwatch_log_retention_days`.  A simple example:
```
    sumologic_filters      = [ "-INFO" ]
```


Metrics from the cluster itself will be sent to DataDog as long as the  `datadog_api_key` variable has been set.  Metrics from the Docker containers themselves must be gathered outside of this module.

## Enabling AWS X-Ray

If you would like to enable AWS X-Ray as a local daemon running on each ECS instance, then pass in `enable_xray = true` in your module.

Currently this agent listens on any interface at `0.0.0.0` on port 2000 for both TCP and UDP. This is because we want the agent to be generic enough on an ECS cluster so that Docker services can communicate with it. For example if you have a Docker container running on ECS that wants to send data to the X-ray agent, then you would use the docker bridge host (eg 172.17.0.1). You would tell your Docker services to use `172.17.0.1:2000` as the X-ray daemon address. This way Docker can reach out of the container and communicate with the X-ray agent on the host.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| ami_search_name | Use the latest AMI whose Name matches this string | string | - | yes |
| cloudwatch_log_retention_days | Number of days to retain logs in CloudWatch Logs.  0 for indefinite.  Does not affect Sumo Logic retention. | string | `7` | no |
| cmk_arn | Grant access to the KMS CMK specified by this ARN. | string | `` | no |
| datadog_api_key | Datadog API key.  Will skip datadog integration if left blank | string | `` | no |
| datadog_docker_image | Datadog agent docker image.| string | `datadog/docker-dd-agent:latest` | no |
| datadog_labels_as_tags | Comma-separated container label names to be used for tagging metrics - see [this link](https://github.com/DataDog/integrations-core/blob/f9efbe00b745491b23927760f13afed57b0ead87/docker_daemon/conf.yaml.example#L187-L194) for details. | string | `` | no |
| desired_capacity | ASG desired_capacity | string | `1` | no |
| ecs_userdata_configuration | Individual commands that will run at launch for each container instance | string | `<list>` | no |
| enable_xray | Enable a local daemon AWS X-Ray agent | string | `false` | no |
| extra_security_groups | List of external security group IDs to apply (if any) to instances in this cluster | string | `<list>` | no |
| extra_tags | Additional tags to be propagated to ec2 instances created by autoscaling group | string | `<list>` | no |
| health_check_grace_period | Time (in seconds) after instance comes into service before checking health | string | `300` | no |
| health_check_type | Type of ASG health check.  'EC2' or 'ELB' | string | `EC2` | no |
| instance_type | Instance type for the cluster | string | `t2.xlarge` | no |
| launch_config_key_name | EC2 SSH keypair name to apply to all container instances.  Defaults to none. | string | `` | no |
| max_size | ASG max_size | string | `1` | no |
| min_size | ASG min_size | string | `1` | no |
| name | The unique name for this ECS cluster | string | - | yes |
| scale_in_protection | Whether to set ECS container instances for scale-in termination protection | string | `false` | no |
| sumologic_endpoint_url | Sumo Logic hosted collector HTTP source URL.  Will skip Sumo Logic integration if left blank | string | `` | no |
| sumologic_filters | CloudWatch log filters to select what will be sent to SumoLogic.  Defaults to all logs.  [Syntax information](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html) | string | `<list>` | no |
| termination_policies | ASG termination policies.  Allowed values: `OldestInstance`, `NewestInstance`, `OldestLaunchConfiguration`, `ClosestToNextInstanceHour`, `Default` | list | `<list>` | no |
| vpc_id | The ID of the VPC for this cluster | string | - | yes |
| vpc_zone_identifier | List of subnet IDs to launch resources in | list | - | yes |
| enable_secondary_asg | Enable creation of a secondary autoscaling group (true/false). | bool | `false` | no |
| secondary_asg_options | A map to specify instance_type, min_size and max_size of the secondary ASG | map | `See variables.tf` | no |

## Outputs

| Name | Description |
|------|-------------|
| ecs_autoscaling_group_name | Name of the AWS Autoscaling group |
| ecs_cluster_arn | ARN for the ECS cluster |
| ecs_cluster_name | Name of the ECS cluster |
