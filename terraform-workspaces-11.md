# Terraform Workspaces - Managing Multiple Environments

Terraform workspaces are like having separate universes for your infrastructure. Each workspace maintains its own state file, allowing you to deploy the same configuration to different environments without conflicts.

## The Multi-Environment Challenge

Imagine you're building a web application. You need:
- **Development environment** - for testing new features
- **Staging environment** - for final testing before release
- **Production environment** - for real users

Without workspaces, you'd need separate Terraform configurations for each environment, leading to code duplication and maintenance nightmares.

**The Problem:**
```
web-app-dev/
├── main.tf (duplicate code)
├── variables.tf (duplicate code)
└── terraform.tfstate

web-app-staging/
├── main.tf (same code, different values)
├── variables.tf (same code, different values)
└── terraform.tfstate

web-app-prod/
├── main.tf (same code again!)
├── variables.tf (same code again!)
└── terraform.tfstate
```

**The Solution with Workspaces:**
```
web-app/
├── main.tf (single configuration)
├── variables.tf (single configuration)
├── terraform.tfstate.d/
│   ├── dev/
│   │   └── terraform.tfstate
│   ├── staging/
│   │   └── terraform.tfstate
│   └── prod/
│       └── terraform.tfstate
```

## Understanding Workspaces

Every Terraform configuration starts with a `default` workspace. You can create additional workspaces to isolate different environments.

### Basic Workspace Commands

```bash
# List all workspaces (* shows current)
terraform workspace list

# Show current workspace
terraform workspace show

# Create new workspace
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Switch between workspaces
terraform workspace select dev
terraform workspace select prod

# Delete workspace (must be empty)
terraform workspace delete old-feature
```

### Your First Multi-Environment Setup

Let's create a simple web server that adapts to different environments:

```
# main.tf
locals {
  # Environment-specific configurations
  environments = {
    dev = {
      instance_count = 1
      instance_size  = "small"
      backup_enabled = false
    }
    staging = {
      instance_count = 2
      instance_size  = "medium"
      backup_enabled = true
    }
    prod = {
      instance_count = 3
      instance_size  = "large"
      backup_enabled = true
    }
  }
  
  # Get current environment config
  current_env = local.environments[terraform.workspace]
}

# Create environment-specific server configuration
resource "local_file" "server_config" {
  filename = "${terraform.workspace}-server.conf"
  content = <<-EOF
    # Server configuration for ${terraform.workspace}
    environment = ${terraform.workspace}
    instance_count = ${local.current_env.instance_count}
    instance_size = ${local.current_env.instance_size}
    backup_enabled = ${local.current_env.backup_enabled}
    
    # Generated on: ${timestamp()}
  EOF
}

# Create backup script only for environments that need it
resource "local_file" "backup_script" {
  count = local.current_env.backup_enabled ? 1 : 0
  
  filename = "${terraform.workspace}-backup.sh"
  content = <<-EOF
    #!/bin/bash
    echo "Running backup for ${terraform.workspace} environment"
    echo "Instance count: ${local.current_env.instance_count}"
    echo "Backup retention: ${terraform.workspace == "prod" ? "90 days" : "30 days"}"
  EOF
}

# Output environment information
output "environment_info" {
  value = {
    workspace = terraform.workspace
    config = local.current_env
    files_created = concat(
      [local_file.server_config.filename],
      local.current_env.backup_enabled ? [local_file.backup_script[0].filename] : []
    )
  }
}
```

Now you can deploy to different environments:

```bash
# Deploy to development
terraform workspace select dev
terraform apply

# Deploy to staging
terraform workspace select staging
terraform apply

# Deploy to production
terraform workspace select prod
terraform apply
```

Each workspace creates its own files with environment-specific configurations!

## Remote State with Workspaces

For team collaboration, you need remote state storage. Here's how to set up S3 backend with workspace support:

### Basic S3 Backend Setup

```
# backend.tf
terraform {
  backend "s3" {
    bucket = "my-company-terraform-state"
    key    = "web-app/terraform.tfstate"
    region = "us-west-2"
    
    # Enable state locking
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
```

This creates separate state files for each workspace:
```
s3://my-company-terraform-state/
└── web-app/
    ├── env:/dev/terraform.tfstate
    ├── env:/staging/terraform.tfstate
    └── env:/prod/terraform.tfstate
```

### Advanced Backend Configuration

For better organization, include workspace in the key path:

```
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "projects/web-app/${terraform.workspace}/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
```

This creates a cleaner structure:
```
projects/web-app/dev/terraform.tfstate
projects/web-app/staging/terraform.tfstate
projects/web-app/prod/terraform.tfstate
```

### State Locking in Action

Without locking:
```
Person A: terraform apply  ← starts
Person B: terraform apply  ← starts at same time
Result: 💥 CONFLICT! State corruption!
```

With locking:
```
Person A: terraform apply  ← starts, gets lock
Person B: terraform apply  ← waits for lock
Person A: finishes         ← releases lock
Person B: now can proceed  ← gets lock and continues
```

DynamoDB provides the locking mechanism automatically when you specify the `dynamodb_table`.

## Environment-Specific Configurations

Here's a practical pattern for handling different environment needs:

```
locals {
  # Environment-specific configurations
  environments = {
    dev = {
      instance_type     = "t3.micro"
      min_size         = 1
      max_size         = 2
      enable_backup    = false
      enable_monitoring = false
      domain_prefix    = "dev"
    }
    staging = {
      instance_type     = "t3.small"
      min_size         = 2
      max_size         = 4
      enable_backup    = true
      enable_monitoring = true
      domain_prefix    = "staging"
    }
    prod = {
      instance_type     = "t3.medium"
      min_size         = 3
      max_size         = 10
      enable_backup    = true
      enable_monitoring = true
      domain_prefix    = "www"
    }
  }
  
  # Get current environment config
  env = local.environments[terraform.workspace]
  
  # Common settings
  common_tags = {
    Environment   = terraform.workspace
    Project       = "web-app"
    ManagedBy    = "terraform"
    LastModified = timestamp()
  }
}

# Use environment-specific settings
resource "local_file" "app_config" {
  filename = "${terraform.workspace}-app-config.json"
  content = jsonencode({
    environment = terraform.workspace
    
    # Environment-specific settings
    instance_type = local.env.instance_type
    scaling = {
      min_size = local.env.min_size
      max_size = local.env.max_size
    }
    features = {
      backup     = local.env.enable_backup
      monitoring = local.env.enable_monitoring
    }
    
    # Computed values
    domain_name = "${local.env.domain_prefix}.mycompany.com"
    
    # Common settings
    tags = local.common_tags
  })
}

# Create backup configuration only if enabled
resource "local_file" "backup_config" {
  count = local.env.enable_backup ? 1 : 0
  
  filename = "${terraform.workspace}-backup.conf"
  content = <<-EOF
    # Backup configuration for ${terraform.workspace}
    retention_days = ${terraform.workspace == "prod" ? 90 : 30}
    backup_frequency = ${terraform.workspace == "prod" ? "hourly" : "daily"}
    
    # Environment: ${terraform.workspace}
    # Generated: ${timestamp()}
  EOF
}

output "environment_summary" {
  value = {
    workspace       = terraform.workspace
    instance_type   = local.env.instance_type
    scaling_range   = "${local.env.min_size}-${local.env.max_size}"
    backup_enabled  = local.env.enable_backup
    monitoring      = local.env.enable_monitoring
    domain_name     = "${local.env.domain_prefix}.mycompany.com"
    files_created   = concat(
      [local_file.app_config.filename],
      local.env.enable_backup ? [local_file.backup_config[0].filename] : []
    )
  }
}
```

## Team Collaboration Best Practices

### 1. Shared Remote State
Everyone on the team uses the same S3 bucket for state storage.

### 2. Clear Workspace Naming
Use consistent workspace names that everyone understands:
- `dev` (or `development`)
- `staging` (or `stage`)
- `prod` (or `production`)

### 3. Workspace Ownership
- **dev**: Developers can create/destroy freely
- **staging**: Shared by team, coordinate changes
- **prod**: Protected, require approval for changes

### 4. State File Organization
```
terraform-state-bucket/
├── project-web-app/
├── project-api/
├── project-database/
└── shared-infrastructure/
```

### 5. Access Controls
Different team members get different permissions:
- **Developers**: Full access to dev, read-only on staging/prod
- **DevOps**: Full access to all environments
- **QA**: Read access to staging for testing validation

## Workspace Security Considerations

### Separate AWS Accounts
For maximum security, use different AWS accounts:

```
terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "web-app/terraform.tfstate"
    region = "us-west-2"
    
    # Use different accounts based on workspace
    role_arn = terraform.workspace == "prod" ? 
      "arn:aws:iam::PROD-ACCOUNT:role/TerraformRole" :
      "arn:aws:iam::DEV-ACCOUNT:role/TerraformRole"
  }
}
```

### Environment-Specific Secrets

```
locals {
  # Different secrets per environment
  database_passwords = {
    dev     = "simple_dev_password"
    staging = var.staging_db_password  # From environment variable
    prod    = var.prod_db_password     # From secure vault
  }
  
  db_password = local.database_passwords[terraform.workspace]
}
```

## Common Workspace Patterns

### Pattern 1: Feature Branches

```bash
# Create workspace for feature development
terraform workspace new feature-user-auth
# Work on feature
terraform workspace select feature-user-auth
terraform apply
# When done, clean up
terraform destroy
terraform workspace select default
terraform workspace delete feature-user-auth
```

### Pattern 2: Developer Workspaces

```bash
# Each developer gets their own workspace
terraform workspace new dev-alice
terraform workspace new dev-bob
terraform workspace new dev-charlie
```

### Pattern 3: Environment Promotion

```bash
# Deploy to dev first
terraform workspace select dev
terraform apply

# Test in dev, then promote to staging
terraform workspace select staging  
terraform apply

# Test in staging, then promote to prod
terraform workspace select prod
terraform apply
```

## Troubleshooting Common Issues

### Issue: "Workspace doesn't exist"

```
Error: Workspace "staging" doesn't exist.
```

**Solution:**
```bash
terraform workspace new staging
```

### Issue: "State lock timeout"

```
Error: Error acquiring the state lock
```

**Solution:**
```bash
# Someone else is running terraform, wait for them to finish
# Or if process crashed, force unlock (dangerous!)
terraform force-unlock LOCK_ID
```

### Issue: "Backend configuration changed"

```
Error: Backend configuration changed
```

**Solution:**
```bash
terraform init -reconfigure
```

### Issue: "Wrong workspace"

```bash
# Always check current workspace before applying!
terraform workspace show

# Switch to correct workspace
terraform workspace select prod
```

## Workspace Limitations and Alternatives

### Workspace Limitations:
- All workspaces use the same Terraform code
- Can't have drastically different architectures
- Workspace names are global per backend
- Limited to one backend per configuration

### When NOT to Use Workspaces:
- **Different cloud providers**: Use separate configurations
- **Completely different architectures**: Use separate projects
- **Different teams**: Use separate state buckets
- **Different compliance requirements**: Use separate everything

### Alternative Approaches:

**Separate directories approach:**
```
projects/
├── web-app-dev/
├── web-app-staging/
└── web-app-prod/
```

**Separate repositories approach:**
```
web-app-dev-terraform/
web-app-staging-terraform/
web-app-prod-terraform/
```

**Terragrunt approach (advanced tool):**
```
environments/
├── dev/
├── staging/
└── prod/
```

## Advanced Workspace Techniques

### Dynamic Resource Naming

```
locals {
  # Create unique names per workspace
  resource_prefix = "${var.project_name}-${terraform.workspace}"
}

resource "local_file" "app_config" {
  filename = "${local.resource_prefix}-config.json"
  content = jsonencode({
    app_name = local.resource_prefix
    environment = terraform.workspace
  })
}
```

### Conditional Resource Creation

```
# Only create monitoring in staging and prod
resource "local_file" "monitoring_config" {
  count = contains(["staging", "prod"], terraform.workspace) ? 1 : 0
  
  filename = "${terraform.workspace}-monitoring.conf"
  content = "monitoring_enabled = true"
}

# Different configurations per environment
resource "local_file" "database_config" {
  filename = "${terraform.workspace}-db.conf"
  content = terraform.workspace == "prod" ? 
    "connection_pool_size = 100" : 
    "connection_pool_size = 10"
}
```

### Workspace-Aware Modules

```
module "web_server" {
  source = "./modules/web-server"
  
  environment = terraform.workspace
  instance_count = terraform.workspace == "prod" ? 3 : 1
  enable_ssl = terraform.workspace != "dev"
}
```

## Quick Reference

### Workspace Commands:
```bash
terraform workspace list              # Show all workspaces
terraform workspace show              # Show current workspace
terraform workspace new NAME          # Create new workspace
terraform workspace select NAME       # Switch to workspace
terraform workspace delete NAME       # Delete workspace
```

### Remote State Backend:
```
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "project/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### Environment-Specific Logic:
```
locals {
  is_prod = terraform.workspace == "prod"
  config = local.environments[terraform.workspace]
}
```

## What's Next?

You've mastered Terraform workspaces for professional environment management:

### Workspace Fundamentals:
- ✅ Understanding workspace isolation and benefits
- ✅ Creating and switching between workspaces
- ✅ Using terraform.workspace for environment-specific logic
- ✅ Organizing workspace-specific configurations

### Remote State Management:
- ✅ Setting up S3 backend with DynamoDB locking
- ✅ Team collaboration with shared state
- ✅ State security and access control
- ✅ Troubleshooting common state issues

### Professional Practices:
- ✅ Environment-specific configurations and patterns
- ✅ Workspace naming and organization strategies
- ✅ Security considerations for production environments
- ✅ When to use workspaces vs alternative approaches

Workspaces are your key to managing multiple environments efficiently while maintaining a single, maintainable codebase!