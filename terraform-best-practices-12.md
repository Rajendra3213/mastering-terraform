# Terraform Best Practices - Production-Ready Infrastructure Code

Writing Terraform code that works is easy. Writing Terraform code that scales, is maintainable, and doesn't break in production is an art. This guide covers the battle-tested practices that separate hobbyist code from enterprise-grade infrastructure.

## The Foundation: Code Organization

### Project Structure That Scales

```
terraform-infrastructure/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   ├── staging/
│   └── prod/
├── modules/
│   ├── vpc/
│   ├── database/
│   └── web-app/
├── shared/
│   ├── data-sources.tf
│   └── providers.tf
└── scripts/
    ├── deploy.sh
    └── validate.sh
```

**Why this structure works:**
- **Environments are isolated** - No accidental prod changes
- **Modules are reusable** - Write once, use everywhere
- **Shared resources are centralized** - Common configurations in one place
- **Scripts automate workflows** - Consistent deployment processes

### File Naming Conventions

```
# Core files (in order of execution)
providers.tf      # Provider configurations
versions.tf       # Version constraints
data.tf          # Data sources
locals.tf        # Local values
main.tf          # Primary resources
variables.tf     # Input variables
outputs.tf       # Output values
```

## Variable Design Patterns

### The Good: Descriptive and Validated

```
variable "database_instance_class" {
  type        = string
  description = "RDS instance class (e.g., db.t3.micro, db.r5.large)"
  
  validation {
    condition = can(regex("^db\\.(t3|r5|m5)\\.(micro|small|medium|large|xlarge)$", var.database_instance_class))
    error_message = "Instance class must be a valid RDS instance type."
  }
}

variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "backup_retention_days" {
  type        = number
  description = "Number of days to retain automated backups"
  default     = 7
  
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "Backup retention must be between 1 and 35 days."
  }
}
```

### The Bad: Vague and Unvalidated

```
# Don't do this
variable "size" {
  type = string
}

variable "config" {
  type = map(any)
}

variable "enable_stuff" {
  type = bool
}
```

## Resource Naming and Tagging

### Consistent Naming Strategy

```
locals {
  # Naming convention: {project}-{environment}-{service}-{resource}
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Standard tags applied to all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.team_name
    CostCenter  = var.cost_center
    CreatedDate = formatdate("YYYY-MM-DD", timestamp())
  }
}

# Example resource with consistent naming and tagging
resource "aws_instance" "web_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-server"
    Role = "web-server"
  })
}
```

### Tag Strategy for Cost Management

```
locals {
  # Cost allocation tags
  cost_tags = {
    CostCenter    = var.cost_center
    Project       = var.project_name
    Environment   = var.environment
    Team          = var.team_name
    Application   = var.application_name
  }
  
  # Operational tags
  operational_tags = {
    ManagedBy     = "terraform"
    BackupPolicy  = var.backup_required ? "daily" : "none"
    Monitoring    = var.monitoring_enabled ? "enabled" : "disabled"
    Compliance    = var.compliance_level
  }
  
  # Merge all tags
  all_tags = merge(local.cost_tags, local.operational_tags)
}
```

## State Management Best Practices

### Remote State Configuration

```
# backend.tf
terraform {
  backend "s3" {
    bucket         = "company-terraform-state-prod"
    key            = "infrastructure/web-app/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    
    # State locking
    dynamodb_table = "terraform-state-locks"
    
    # Versioning and lifecycle
    versioning = true
  }
  
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### State File Security

```
# S3 bucket policy for state files
data "aws_iam_policy_document" "terraform_state_policy" {
  statement {
    sid    = "DenyInsecureConnections"
    effect = "Deny"
    
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    
    actions = ["s3:*"]
    
    resources = [
      aws_s3_bucket.terraform_state.arn,
      "${aws_s3_bucket.terraform_state.arn}/*"
    ]
    
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}
```

## Building Production-Ready Modules

### Module Design Principles

1. **Single Responsibility** - Each module has one clear purpose
2. **Composability** - Modules work together seamlessly
3. **Convention Over Configuration** - Sensible defaults with override options
4. **Progressive Disclosure** - Simple by default, complex when needed

### Essential Module Components

```
# modules/web-app/variables.tf
variable "name" {
  type        = string
  description = "Name of the web application"
}

variable "environment" {
  type        = string
  description = "Environment (dev, staging, prod)"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "instance_config" {
  type = object({
    instance_type = string
    min_size      = number
    max_size      = number
    desired_size  = number
  })
  description = "EC2 instance configuration"
  
  default = {
    instance_type = "t3.micro"
    min_size      = 1
    max_size      = 3
    desired_size  = 1
  }
}

variable "enable_monitoring" {
  type        = bool
  description = "Enable CloudWatch monitoring"
  default     = true
}

# modules/web-app/main.tf
locals {
  name_prefix = "${var.name}-${var.environment}"
  
  common_tags = {
    Name        = local.name_prefix
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Launch template for web servers
resource "aws_launch_template" "web_app" {
  name_prefix   = "${local.name_prefix}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_config.instance_type
  
  vpc_security_group_ids = [aws_security_group.web_app.id]
  
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    app_name = var.name
  }))
  
  tag_specifications {
    resource_type = "instance"
    tags          = local.common_tags
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web_app" {
  name                = local.name_prefix
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = [aws_lb_target_group.web_app.arn]
  
  min_size         = var.instance_config.min_size
  max_size         = var.instance_config.max_size
  desired_capacity = var.instance_config.desired_size
  
  launch_template {
    id      = aws_launch_template.web_app.id
    version = "$Latest"
  }
  
  tag {
    key                 = "Name"
    value               = local.name_prefix
    propagate_at_launch = true
  }
}

# modules/web-app/outputs.tf
output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = aws_lb.web_app.dns_name
}

output "security_group_id" {
  description = "ID of the web app security group"
  value       = aws_security_group.web_app.id
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.web_app.arn
}
```

## Security Best Practices

### Secrets Management

```
# Generate random passwords
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# Store in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${local.name_prefix}-db-password"
  description             = "Database password for ${var.name}"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

# Use in RDS instance
resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-db"
  
  engine         = "postgres"
  engine_version = "13.7"
  instance_class = var.db_instance_class
  
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result
  
  # Security settings
  encrypted               = true
  storage_encrypted       = true
  backup_retention_period = var.backup_retention_days
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  # Network security
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]
  
  # Prevent accidental deletion
  deletion_protection = var.environment == "prod"
  skip_final_snapshot = var.environment != "prod"
  
  tags = local.common_tags
}
```

### Network Security Patterns

```
# Security group with least privilege
resource "aws_security_group" "web_app" {
  name_prefix = "${local.name_prefix}-web-"
  vpc_id      = var.vpc_id
  
  # Allow HTTP from load balancer only
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer.id]
  }
  
  # Allow HTTPS from load balancer only
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer.id]
  }
  
  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-sg"
  })
}

# Database security group
resource "aws_security_group" "database" {
  name_prefix = "${local.name_prefix}-db-"
  vpc_id      = var.vpc_id
  
  # Allow database access from web servers only
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_app.id]
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-sg"
  })
}
```

## Testing Your Terraform Code

### Static Analysis Setup

```yaml
# .github/workflows/terraform.yml
name: Terraform CI/CD

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0
      
      - name: Terraform Format Check
        run: terraform fmt -check -recursive
      
      - name: Terraform Init
        run: terraform init -backend=false
      
      - name: Terraform Validate
        run: terraform validate
      
      - name: TFSec Security Scan
        uses: aquasecurity/tfsec-action@v1.0.3
        with:
          soft_fail: true
      
      - name: Checkov Scan
        uses: bridgecrewio/checkov-action@master
        with:
          directory: .
          framework: terraform
```

### Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.81.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
        args:
          - --hook-config=--path-to-file=README.md
          - --hook-config=--add-to-existing-file=true
          - --hook-config=--create-file-if-not-exist=true
      - id: terraform_tflint
        args:
          - --args=--only=terraform_deprecated_interpolation
          - --args=--only=terraform_deprecated_index
          - --args=--only=terraform_unused_declarations
          - --args=--only=terraform_comment_syntax
          - --args=--only=terraform_documented_outputs
          - --args=--only=terraform_documented_variables
          - --args=--only=terraform_typed_variables
          - --args=--only=terraform_module_pinned_source
          - --args=--only=terraform_naming_convention
          - --args=--only=terraform_required_version
          - --args=--only=terraform_required_providers
          - --args=--only=terraform_standard_module_structure
          - --args=--only=terraform_workspace_remote
```

## CI/CD Pipeline Best Practices

### Multi-Stage Pipeline

```yaml
# .github/workflows/deploy.yml
name: Deploy Infrastructure

on:
  push:
    branches: [main]

jobs:
  plan:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-west-2
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
      
      - name: Terraform Init
        working-directory: environments/${{ matrix.environment }}
        run: terraform init
      
      - name: Terraform Plan
        working-directory: environments/${{ matrix.environment }}
        run: |
          terraform plan \
            -var-file=terraform.tfvars \
            -out=tfplan \
            -no-color
      
      - name: Upload Plan
        uses: actions/upload-artifact@v3
        with:
          name: tfplan-${{ matrix.environment }}
          path: environments/${{ matrix.environment }}/tfplan

  deploy-dev:
    needs: plan
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Download Plan
        uses: actions/download-artifact@v3
        with:
          name: tfplan-dev
          path: environments/dev/
      
      - name: Terraform Apply
        working-directory: environments/dev
        run: terraform apply tfplan

  deploy-staging:
    needs: [plan, deploy-dev]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - name: Wait for Approval
        uses: trstringer/manual-approval@v1
        with:
          approvers: platform-team
          minimum-approvals: 1
      
      # Similar apply steps...

  deploy-prod:
    needs: [plan, deploy-staging]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - name: Wait for Approval
        uses: trstringer/manual-approval@v1
        with:
          approvers: platform-team,security-team
          minimum-approvals: 2
      
      # Similar apply steps...
```

## Documentation Standards

### Module Documentation Template

```markdown
# Web Application Module

This module creates a scalable web application infrastructure with:
- Auto Scaling Group with Launch Template
- Application Load Balancer
- Security Groups with least privilege access
- CloudWatch monitoring and alarms

## Usage

```hcl
module "web_app" {
  source = "./modules/web-app"
  
  name        = "my-app"
  environment = "prod"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids
  
  instance_config = {
    instance_type = "t3.medium"
    min_size      = 2
    max_size      = 10
    desired_size  = 3
  }
  
  enable_monitoring = true
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | ~> 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name of the web application | `string` | n/a | yes |
| environment | Environment (dev, staging, prod) | `string` | n/a | yes |
| vpc_id | ID of the VPC | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| load_balancer_dns | DNS name of the load balancer |
| security_group_id | ID of the web app security group |

## Examples

See the [examples](./examples/) directory for complete usage examples.
```

## Common Anti-Patterns to Avoid

### 1. Hardcoded Values

```
# Bad
resource "aws_instance" "web" {
  ami           = "ami-12345678"  # Hardcoded AMI
  instance_type = "t3.micro"     # Hardcoded instance type
  subnet_id     = "subnet-12345" # Hardcoded subnet
}

# Good
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
}
```

### 2. Overly Complex Modules

```
# Bad - trying to do everything
module "entire_application" {
  source = "./modules/everything"
  
  # 50+ variables for different services
}

# Good - focused modules
module "vpc" {
  source = "./modules/vpc"
}

module "database" {
  source = "./modules/database"
  vpc_id = module.vpc.vpc_id
}

module "web_app" {
  source = "./modules/web-app"
  vpc_id = module.vpc.vpc_id
  db_endpoint = module.database.endpoint
}
```

### 3. Poor Error Handling

```
# Bad - no validation
variable "environment" {
  type = string
}

# Good - with validation
variable "environment" {
  type        = string
  description = "Environment name"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
```

## Cost Optimization Strategies

### Resource Tagging for Cost Allocation

```
locals {
  cost_allocation_tags = {
    CostCenter   = var.cost_center
    Project      = var.project_name
    Environment  = var.environment
    Team         = var.team_name
    Application  = var.application_name
    Owner        = var.owner_email
  }
}

# Apply to all resources
resource "aws_instance" "web" {
  # ... other configuration
  
  tags = merge(local.cost_allocation_tags, {
    Name = "${local.name_prefix}-web-server"
    Role = "web-server"
  })
}
```

### Environment-Specific Sizing

```
locals {
  environment_configs = {
    dev = {
      instance_type = "t3.micro"
      min_size      = 1
      max_size      = 2
    }
    staging = {
      instance_type = "t3.small"
      min_size      = 1
      max_size      = 3
    }
    prod = {
      instance_type = "t3.medium"
      min_size      = 2
      max_size      = 10
    }
  }
  
  config = local.environment_configs[var.environment]
}
```

## Disaster Recovery Planning

### Multi-Region Setup

```
# Primary region resources
module "primary_region" {
  source = "./modules/web-app"
  
  providers = {
    aws = aws.primary
  }
  
  name        = var.application_name
  environment = var.environment
  is_primary  = true
}

# DR region resources
module "dr_region" {
  source = "./modules/web-app"
  
  providers = {
    aws = aws.dr
  }
  
  name        = var.application_name
  environment = var.environment
  is_primary  = false
  
  # Smaller capacity for DR
  instance_config = {
    instance_type = "t3.small"
    min_size      = 1
    max_size      = 3
    desired_size  = 1
  }
}
```

### Backup Strategies

```
# Automated backups
resource "aws_db_instance" "main" {
  # ... other configuration
  
  backup_retention_period = var.environment == "prod" ? 30 : 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  # Point-in-time recovery
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  # Automated snapshots
  copy_tags_to_snapshot = true
  
  tags = local.common_tags
}

# Additional backup for critical data
resource "aws_db_snapshot" "manual_snapshot" {
  count = var.create_manual_snapshot ? 1 : 0
  
  db_instance_identifier = aws_db_instance.main.id
  db_snapshot_identifier = "${local.name_prefix}-manual-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  
  tags = local.common_tags
}
```

## What's Next?

You now have a comprehensive playbook for production-ready Terraform:

### Foundation Practices:
- ✅ Scalable project structure and file organization
- ✅ Proper variable design with validation
- ✅ Consistent naming and tagging strategies
- ✅ Secure state management

### Advanced Techniques:
- ✅ Production-ready module development
- ✅ Security best practices and secrets management
- ✅ Comprehensive testing strategies
- ✅ CI/CD pipeline implementation

### Operational Excellence:
- ✅ Cost optimization and allocation
- ✅ Disaster recovery planning
- ✅ Documentation standards
- ✅ Common anti-patterns to avoid

### Keep Learning:
- Join the Terraform community (Discord, Reddit, HashiCorp forums)
- Contribute to open-source Terraform modules
- Stay updated with new Terraform features
- Explore advanced topics like Policy as Code and GitOps

Remember: Great infrastructure code isn't about being clever – it's about being clear, consistent, and maintainable. Start with the basics, improve incrementally, and always prioritize clarity over cleverness.