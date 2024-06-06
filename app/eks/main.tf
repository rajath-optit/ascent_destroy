module "eks" {
  source = "../../modules/eks"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
  # Add necessary variables and configurations
}

# Data source to fetch VPC subnets
data "aws_subnet_ids" "vpc_subnets" {
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
}

data "aws_subnet" "subnets" {
  count = length(data.aws_subnet_ids.vpc_subnets.ids)
  id    = data.aws_subnet_ids.vpc_subnets.ids[count.index]
}

# Resource to update subnet tags
resource "aws_subnet" "add_tags" {
  for_each = { for subnet in data.aws_subnet.subnets : subnet.id => subnet }

  subnet_id = each.key

  tags = merge(
    each.value.tags,
    {
      "AdditionalTagKey" = "AdditionalTagValue"
      # Add more tags as needed
    }
  )
}
