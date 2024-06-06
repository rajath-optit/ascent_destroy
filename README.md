# Terraform AWS Infrastructure

This repository contains Terraform configurations to set up AWS infrastructure, including a VPC and EKS cluster, and a GitHub Actions workflow to destroy the Terraform-managed resources.

## Directory Structure

```
app
  └── vpc
      ├── main.tf
      ├── provider.tf
  └── eks
      ├── main.tf
      ├── provider.tf
modules
  └── vpc
  └── eks
.github
  └── workflows
      └── destroy-terraform-resources.yml
```

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) (version 1.0.0 or later)
- AWS account with appropriate IAM permissions
- An S3 bucket to store Terraform state files
- GitHub repository to host the code and run the GitHub Actions workflow

## Setting Up the Environment

### 1. Define VPC Module

Create the following files for the VPC module in `modules/vpc`:

#### `modules/vpc/main.tf`

```hcl
resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "public" {
  count             = var.public_subnet_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.public_subnets_cidr_blocks, count.index)
  availability_zone = element(var.availability_zones, count.index)
  tags = {
    Name = "public-subnet-${count.index}"
  }
}

resource "aws_subnet" "private" {
  count             = var.private_subnet_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_subnets_cidr_blocks, count.index)
  availability_zone = element(var.availability_zones, count.index)
  tags = {
    Name = "private-subnet-${count.index}"
  }
}

output "vpc_id" {
  value = aws_vpc.main.id
}
```

#### `modules/vpc/variables.tf`

```hcl
variable "cidr_block" {
  type = string
}

variable "public_subnet_count" {
  type = number
}

variable "public_subnets_cidr_blocks" {
  type = list(string)
}

variable "private_subnet_count" {
  type = number
}

variable "private_subnets_cidr_blocks" {
  type = list(string)
}

variable "availability_zones" {
  type = list(string)
}
```

### 2. Define EKS Module

Create the following files for the EKS module in `modules/eks`:

#### `modules/eks/main.tf`

```hcl
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids = var.subnet_ids
  }
}

output "eks_cluster_id" {
  value = aws_eks_cluster.main.id
}
```

#### `modules/eks/variables.tf`

```hcl
variable "cluster_name" {
  type = string
}

variable "cluster_role_arn" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}
```

### 3. Set Up VPC

Create the following files in `app/vpc`:

#### `app/vpc/main.tf`

```hcl
module "vpc" {
  source = "../../modules/vpc"
  cidr_block = "10.0.0.0/16"
  public_subnet_count = 2
  public_subnets_cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_count = 2
  private_subnets_cidr_blocks = ["10.0.3.0/24", "10.0.4.0/24"]
  availability_zones = ["us-west-2a", "us-west-2b"]
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
```

#### `app/vpc/provider.tf`

```hcl
provider "aws" {
  region = "us-west-2"
}

terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "vpc/terraform.tfstate"
    region = "us-west-2"
  }
}
```

### 4. Set Up EKS

Create the following files in `app/eks`:

#### `app/eks/main.tf`

```hcl
module "eks" {
  source = "../../modules/eks"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
  cluster_name = "my-cluster"
  cluster_role_arn = "arn:aws:iam::123456789012:role/EKSRole"
  subnet_ids = flatten([data.aws_subnet.public.*.id, data.aws_subnet.private.*.id])
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
```

#### `app/eks/provider.tf`

```hcl
provider "aws" {
  region = "us-west-2"
}

terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "eks/terraform.tfstate"
    region = "us-west-2"
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "your-terraform-state-bucket"
    key    = "vpc/terraform.tfstate"
    region = "us-west-2"
  }
}
```

### 5. Create GitHub Actions Workflow

Create the following workflow file in `.github/workflows`:

#### `.github/workflows/destroy-terraform-resources.yml`

```yaml
name: Destroy Terraform Resources

on:
  workflow_dispatch:
    inputs:
      application_name:
        description: 'Application Name'
        required: true
        default: ''
      aws_resource:
        description: 'AWS Resource'
        required: true
        default: ''

jobs:
  destroy:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout repository
      uses: actions/checkout@v2

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v1
      with:
        terraform_version: 1.0.0

    - name: Terraform Init VPC
      working-directory: ./app/vpc
      run: terraform init

    - name: Terraform Destroy VPC
      working-directory: ./app/vpc
      env:
        TF_VAR_application_name: ${{ github.event.inputs.application_name }}
        TF_VAR_aws_resource: ${{ github.event.inputs.aws_resource }}
      run: terraform destroy -auto-approve

    - name: Terraform Init EKS
      working-directory: ./app/eks
      run: terraform init

    - name: Terraform Destroy EKS
      working-directory: ./app/eks
      env:
        TF_VAR_application_name: ${{ github.event.inputs.application_name }}
        TF_VAR_aws_resource: ${{ github.event.inputs.aws_resource }}
      run: terraform destroy -auto-approve
```

## How to Execute

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/your-repository.git
   cd your-repository
   ```

2. **Initialize Terraform**:
   Navigate to the `app/vpc` directory and initialize Terraform:
   ```bash
   cd app/vpc
   terraform init
   terraform apply -auto-approve
   ```

3. **Apply EKS Configuration**:
   Navigate to the `app/eks` directory and initialize and apply Terraform:
   ```bash
   cd ../eks
   terraform init
   terraform apply -auto-approve
   ```

4. **Run GitHub Actions Workflow**:
   - Go to your GitHub repository.
   - Navigate to the "Actions" tab.
   - Select the "Destroy Terraform Resources" workflow.
   - Click on "Run workflow".
   - Provide the required inputs (application name and AWS resource) and click "Run workflow".

This setup ensures that your Terraform infrastructure is managed and destroyed efficiently using a modular approach and GitHub Actions.
