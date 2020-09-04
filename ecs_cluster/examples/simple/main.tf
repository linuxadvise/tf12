provider "aws" {
  region  = "us-west-2"
  profile = "sandbox"
}

module "ecs-cluster" {
  source           = "../.."
  name             = "ecs-test"
  min_size         = 2
  max_size         = 2
  desired_capacity = 2

  vpc_id              = "vpc-df52fab9"
  vpc_zone_identifier = ["subnet-76d92310", "subnet-de362a97", "subnet-c54bdd9e"]
  ami_search_name     = "nextgen-base-amazon_linux_ecs-*"
}

