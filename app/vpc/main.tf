module "vpc" {
  source = "../../modules/vpc"
  # Add necessary variables and configurations
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
