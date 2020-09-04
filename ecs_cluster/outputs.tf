output "ecs_cluster" {
  value       = aws_ecs_cluster.main
  description = "ECS cluster object"
}

output "ecs_autoscaling_group_name" {
  value       = aws_autoscaling_group.ecs_asg.name
  description = "Name of the AWS Autoscaling group"
}
