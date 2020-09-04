
**Contents:**
 [Configuration details](CONFIG.md)
 [Changelog and release compatibility issues](CHANGELOG.md)
 [Examples](examples)


# ecs_cluster

Terraform module for creating and managing an AWS ECS cluster.


## Quickstart

* Copy the code from ["examples/simple"](examples/simple) to your Terraform project
* Refer to [CONFIG.md](CONFIG.md) and make whatever changes are needed

## Details

ECS is the EC2 Container Service.  It provides an AWS-native infrastructure for running Docker containers.  Detailed information on the service is available on [its official site](https://aws.amazon.com/ecs/), or see "Suggested Reading", below.


Major resources created by this module include:
* Container instance autoscaling groups, security groups, and IAM roles
* Instrumentation pipelines for CloudWatch logs, Sumo Logic, and Datadog

To make full use of a cluster you will still need to add:
* ECS task and service definitions -- see "[examples/test](examples/test)" for a sample task definition
* Inbound security groups for any ports to be reached from outside the cluster

## Suggested Reading

* **AWS documentation**
  * [What is Amazon Elastic Container Service?](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/Welcome.html)
  * Video: [Amazon ECS: Core Concepts](https://www.youtube.com/watch?v=eq4wL2MiNqo)

* **Terraform documentation**
  * ECS tasks: [aws_ecs_task_definition](https://www.terraform.io/docs/providers/aws/r/ecs_task_definition.html)
  * ECS services: [aws_ecs_service](https://www.terraform.io/docs/providers/aws/r/ecs_service.html)
  * ECR repositories: [aws_ecr_repository](https://www.terraform.io/docs/providers/aws/r/ecr_repository.html)





