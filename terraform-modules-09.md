# Terraform Modules - Advanced Patterns and Best Practices

Terraform modules – the secret to writing code once and using it everywhere.

Think of modules like LEGO blocks. Instead of building a new castle from scratch every time, you create reusable pieces (like walls, towers, gates) that you can combine in different ways to build different castles. That's exactly what modules do for your infrastructure!

## The Problem: Copying Code Everywhere

Let's say you've built a great web server setup for one project. It works perfectly! Now you need the same setup for another project. What do you do?

**Option 1: Copy and paste all the code** 😱

```
Project A/
├── main.tf (web server code)
├── variables.tf
└── outputs.tf

Project B/
├── main.tf (same web server code - copied!)
├── variables.tf (copied!)
└── outputs.tf (copied!)
```

This works, but what happens when you find a bug or want to improve the web server? You have to fix it in both places. And if you have 10 projects? You fix it 10 times!

**Option 2: Use modules** 🎉

```
web-server-module/
├── main.tf
├── variables.tf
└── outputs.tf

Project A/
└── main.tf (uses web-server-module)

Project B/
└── main.tf (uses web-server-module)
```

Now when you improve the web server, you fix it once and all projects get the improvement automatically!

## What Are Modules Really?

A module is just a folder with Terraform files that you can reuse. But let's think deeper about what this means.

Every Terraform configuration is actually a module – even the simple files you've been writing! When you run terraform apply in a folder, you're running the "root module."

**Types of modules:**

- **Root module** – your main Terraform files (where you run terraform commands)
- **Child modules** – reusable pieces you call from your main files
- **Published modules** – shared modules from Terraform Registry or Git
- **Local modules** – modules you create for your own projects

## Why Modules Matter: The Theory

Think about how we build things in the real world:

**Houses aren't built from scratch every time. Builders use:**
- Standard door frames (modules)
- Pre-made windows (modules)
- Standard electrical outlets (modules)
- Common plumbing fixtures (modules)

**Software isn't written from scratch every time. Developers use:**
- Libraries (like modules)
- Frameworks (like modules)
- APIs (like modules)
- Components (like modules)

**Infrastructure shouldn't be built from scratch every time.** That's where Terraform modules come in.

## The Module Mindset: Composition Over Repetition

Instead of thinking "I need to build a web application," think:

- "I need a web server module"
- "I need a database module"
- "I need a load balancer module"
- "I need to compose these together"

This is called **composition** – building complex things from simple, reusable parts.

## Benefits of the Module Approach

### 1. Consistency Across Projects
When you use the same database module everywhere, all your databases are configured the same way. No more "why does this database work differently?"

### 2. Reduced Errors
A well-tested module has fewer bugs than code written from scratch every time. Fix a bug once, it's fixed everywhere.

### 3. Faster Development
Instead of spending days writing infrastructure code, you spend minutes configuring modules.

### 4. Knowledge Sharing
Modules capture best practices. When someone figures out the perfect security configuration, everyone can use it.

### 5. Easier Maintenance
Need to update all databases to a new version? Update one module, redeploy everywhere.

### 6. Better Testing
It's easier to thoroughly test one module than to test the same logic scattered across many projects.

## Types of Modules by Purpose

### Infrastructure Modules
- VPC networks
- Security groups
- Load balancers
- Databases

### Application Modules
- Web servers
- API services
- Worker processes
- Monitoring setups

### Security Modules
- IAM roles and policies
- Certificate management
- Secret storage
- Backup systems

### Utility Modules
- Naming conventions
- Tagging standards
- Environment configurations
- Data transformations

## Module Design Philosophy

### Single Responsibility Principle
Each module should do one thing well. A "web server" module shouldn't also manage databases.

### Interface Design
Think of modules like appliances:
- **Inputs (variables)** are like plugs and settings
- **Outputs** are like displays and ports
- **Internal logic** is hidden (you don't need to know how a microwave works to use it)

### Abstraction Levels
Modules can work at different levels:
- **Low-level**: Create a single AWS security group
- **Mid-level**: Create a web server with security group, load balancer, and auto-scaling
- **High-level**: Create an entire application environment

### Flexibility vs Simplicity
There's always a balance:
- **Too simple**: Module only works for one specific case
- **Too flexible**: Module is complicated and hard to use
- **Just right**: Module works for common cases but allows customization

## Your First Simple Module

Let's create a module that makes file backups. First, create this folder structure:

```
terraform-project/
├── main.tf
└── modules/
    └── file-backup/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

**File: modules/file-backup/variables.tf**

```
variable "file_name" {
  type        = string
  description = "Name of the file to backup"
}

variable "file_content" {
  type        = string
  description = "Content of the file"
}

variable "backup_folder" {
  type        = string
  description = "Folder to store backups"
  default     = "backups"
}
```

**File: modules/file-backup/main.tf**

```
# Create the backup folder
resource "local_file" "backup_folder" {
  filename = "${var.backup_folder}/.keep"
  content  = "This folder contains backups"
}

# Create the original file
resource "local_file" "original" {
  filename = var.file_name
  content  = var.file_content
}

# Create the backup file
resource "local_file" "backup" {
  filename = "${var.backup_folder}/${var.file_name}.backup"
  content  = var.file_content
  
  depends_on = [local_file.backup_folder]
}

# Create a backup info file
resource "local_file" "backup_info" {
  filename = "${var.backup_folder}/${var.file_name}.info"
  content = <<-EOF
    Backup Information
    ==================
    Original file: ${var.file_name}
    Backup created: ${timestamp()}
    File size: ${length(var.file_content)} characters
  EOF
  
  depends_on = [local_file.backup_folder]
}
```

**File: modules/file-backup/outputs.tf**

```
output "original_file" {
  description = "Path to the original file"
  value       = local_file.original.filename
}

output "backup_file" {
  description = "Path to the backup file"
  value       = local_file.backup.filename
}

output "backup_info" {
  description = "Path to the backup info file"
  value       = local_file.backup_info.filename
}

output "files_created" {
  description = "All files created by this module"
  value = {
    original = local_file.original.filename
    backup   = local_file.backup.filename
    info     = local_file.backup_info.filename
  }
}
```

## Using Your Module

Now let's use this module in your main Terraform file:

**File: main.tf**

```
# Use the module to backup important files
module "config_backup" {
  source = "./modules/file-backup"
  
  file_name    = "app-config.json"
  file_content = jsonencode({
    app_name = "MyApp"
    version  = "1.0"
    settings = {
      debug   = true
      timeout = 30
    }
  })
}

module "secrets_backup" {
  source = "./modules/file-backup"
  
  file_name     = "secrets.env"
  file_content  = "DATABASE_PASSWORD=super_secret_123\nAPI_KEY=abc123xyz"
  backup_folder = "secure-backups"
}

# Show what was created
output "backup_summary" {
  value = {
    config_files  = module.config_backup.files_created
    secret_files  = module.secrets_backup.files_created
  }
}
```

Run this and see the magic:

```bash
terraform init
terraform apply
```

You'll get:
- Two original files
- Two backup files
- Two info files
- Files organized in different folders
- All from one reusable module!

## Module Inputs and Outputs

**Module inputs** are variables – they're how you customize the module for different uses.

**Module outputs** are how the module tells you what it created – so you can use that information elsewhere.

```
module "my_module" {
  source = "./path/to/module"
  
  # Inputs (variables)
  input1 = "value1"
  input2 = "value2"
}

# Using outputs
output "something" {
  value = module.my_module.output_name
}
```

## Real-World Example: Web Server Module

Let's create something more practical – a web server module:

**File: modules/web-server/variables.tf**

```
variable "server_name" {
  type        = string
  description = "Name of the web server"
}

variable "environment" {
  type        = string
  description = "Environment (dev, staging, prod)"
  default     = "dev"
}

variable "port" {
  type        = number
  description = "Port for the web server"
  default     = 8080
}

variable "enable_ssl" {
  type        = bool
  description = "Enable SSL/HTTPS"
  default     = false
}

variable "custom_pages" {
  type        = map(string)
  description = "Custom pages to create"
  default     = {}
}
```

**File: modules/web-server/main.tf**

```
locals {
  server_config = {
    name        = var.server_name
    environment = var.environment
    port        = var.port
    ssl_enabled = var.enable_ssl
  }
  
  default_pages = {
    "index.html" = "<h1>Welcome to ${var.server_name}</h1><p>Environment: ${var.environment}</p>"
    "health.html" = "OK"
  }
  
  all_pages = merge(local.default_pages, var.custom_pages)
}

# Create server configuration file
resource "local_file" "server_config" {
  filename = "${var.server_name}-config.json"
  content  = jsonencode(local.server_config)
}

# Create web pages
resource "local_file" "web_pages" {
  for_each = local.all_pages
  
  filename = "${var.server_name}/${each.key}"
  content  = each.value
}

# Create startup script
resource "local_file" "startup_script" {
  filename = "${var.server_name}/start.sh"
  content = <<-EOF
    #!/bin/bash
    echo "Starting ${var.server_name} server..."
    echo "Environment: ${var.environment}"
    echo "Port: ${var.port}"
    echo "SSL: ${var.enable_ssl ? "enabled" : "disabled"}"
    echo "Server is ready!"
  EOF
}
```

**File: modules/web-server/outputs.tf**

```
output "server_name" {
  description = "Name of the server"
  value       = var.server_name
}

output "server_url" {
  description = "URL to access the server"
  value       = "${var.enable_ssl ? "https" : "http"}://localhost:${var.port}"
}

output "config_file" {
  description = "Path to server configuration file"
  value       = local_file.server_config.filename
}

output "pages_created" {
  description = "List of web pages created"
  value       = keys(local.all_pages)
}

output "server_info" {
  description = "Complete server information"
  value = {
    name        = var.server_name
    environment = var.environment
    port        = var.port
    ssl         = var.enable_ssl
    url         = "${var.enable_ssl ? "https" : "http"}://localhost:${var.port}"
    pages       = keys(local.all_pages)
  }
}
```

## Using the Web Server Module

Now you can create different types of servers easily:

```
# Development web server
module "dev_web" {
  source = "./modules/web-server"
  
  server_name = "dev-api"
  environment = "development"
  port        = 3000
  
  custom_pages = {
    "api/users.json" = jsonencode([{id = 1, name = "Test User"}])
    "debug.html"     = "<h1>Debug Mode Enabled</h1>"
  }
}

# Production web server
module "prod_web" {
  source = "./modules/web-server"
  
  server_name = "prod-api"
  environment = "production"
  port        = 443
  enable_ssl  = true
  
  custom_pages = {
    "api/status.json" = jsonencode({status = "healthy", version = "1.0"})
  }
}

# API server with custom configuration
module "api_server" {
  source = "./modules/web-server"
  
  server_name = "microservice-auth"
  environment = "staging"
  port        = 8080
  
  custom_pages = {
    "login.html"     = "<form>Login Form</form>"
    "api/auth.json"  = jsonencode({endpoints = ["/login", "/logout", "/verify"]})
  }
}
```

This creates three different servers with different configurations, all from the same reusable module!

## Module Architecture Patterns

### Layered Architecture

Organize modules in layers, where higher layers depend on lower layers:

```
Application Layer    │ app-server, web-frontend, api-gateway
     ↑              │
Platform Layer      │ database, cache, message-queue  
     ↑              │
Infrastructure Layer │ vpc, security-groups, load-balancer
     ↑              │
Foundation Layer     │ naming, tagging, policies
```

### Composition Pattern

Build complex infrastructure by combining simple modules:

```
# Instead of one giant "web-application" module
module "network" { ... }
module "database" { ... }
module "web_server" { ... }
module "monitoring" { ... }

# Compose them together
```

### Factory Pattern

Use modules to create different "flavors" of the same thing:

```
module "dev_environment" {
  source = "./modules/environment"
  size   = "small"
  features = ["basic-monitoring"]
}

module "prod_environment" {
  source = "./modules/environment"  
  size   = "large"
  features = ["monitoring", "backup", "security"]
}
```

## Module Communication Patterns

### Direct Output/Input

Modules share data through explicit connections:

```
module "database" { ... }

module "web_server" {
  database_url = module.database.connection_string
}
```

### Shared Data Sources

Modules discover each other through external data:

```
data "aws_vpc" "main" {
  tags = { Name = "main-vpc" }
}

module "web_server" {
  vpc_id = data.aws_vpc.main.id
}
```

### Configuration Management

Modules read from shared configuration:

```
locals {
  config = yamldecode(file("infrastructure-config.yaml"))
}

module "web_server" {
  config = local.config.web_server
}
```

## Module Evolution and Backwards Compatibility

### Additive Changes (Safe)

- Adding new optional variables
- Adding new outputs
- Adding new optional resources

### Breaking Changes (Dangerous)

- Removing or renaming variables
- Changing variable types
- Removing outputs
- Changing resource names

### Migration Strategies

```
# Deprecation approach
variable "old_variable_name" {
  type        = string
  default     = null
  description = "DEPRECATED: Use new_variable_name instead"
}

variable "new_variable_name" {
  type    = string
  default = null
}

locals {
  # Use new variable if provided, fallback to old one
  actual_value = var.new_variable_name != null ? var.new_variable_name : var.old_variable_name
}
```

## Using Modules from Terraform Registry

You don't have to build everything yourself. The Terraform Registry has thousands of pre-built modules.

### Registry Benefits:

- **Community tested**: Modules used by thousands of people
- **Best practices**: Modules often follow cloud provider recommendations
- **Documentation**: Usually well-documented with examples
- **Versioning**: Stable releases you can depend on
- **Maintenance**: Updated by maintainers when cloud providers change APIs

### Registry Considerations:

- **External dependency**: You depend on someone else's code
- **Learning curve**: Each module has its own interface
- **Customization limits**: May not fit your exact needs
- **Security**: Need to trust the module author

### Evaluation criteria for registry modules:

- **Download count**: Popular modules are usually more reliable
- **Recent updates**: Actively maintained modules
- **Documentation quality**: Good examples and clear explanations
- **Issue tracker**: How responsive are maintainers to problems?
- **Source code**: Is the code clean and understandable?

Here's how to use a module from the registry:

```
# Use a VPC module from the registry
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  
  name = "my-vpc"
  cidr = "10.0.0.0/16"
  
  azs             = ["us-west-2a", "us-west-2b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  
  enable_nat_gateway = true
  enable_vpn_gateway = true
  
  tags = {
    Environment = "dev"
    Project     = "my-project"
  }
}

# Use the VPC outputs in other resources
output "vpc_info" {
  value = {
    vpc_id          = module.vpc.vpc_id
    private_subnets = module.vpc.private_subnets
    public_subnets  = module.vpc.public_subnets
  }
}
```

**What's different:**

- `source` points to the registry instead of a local path
- `version` specifies which version to use
- The module has different variables than our custom ones

## Passing Data Between Modules

Modules can share data with each other through outputs and inputs:

```
# First module creates network
module "network" {
  source = "./modules/web-server"
  
  server_name = "network-config"
  environment = "prod"
}

# Second module uses data from first module
module "application" {
  source = "./modules/web-server"
  
  server_name = "app-server"
  environment = "prod"
  
  # Use output from network module
  port = 8080  # Could use module.network.server_info.port if it made sense
}

# Show how they're connected
output "module_connection" {
  value = {
    network_url = module.network.server_url
    app_url     = module.application.server_url
    connection  = "App server talks to network on ${module.network.server_info.url}"
  }
}
```

## Module Best Practices

### 1. Keep modules focused

Each module should do one thing well:

```
# Good - focused modules
module "database" { ... }
module "web_server" { ... }
module "load_balancer" { ... }

# Not great - does too many things
module "entire_application" { ... }
```

### 2. Use clear variable names and descriptions

```
variable "database_instance_type" {
  type        = string
  description = "The instance type for the database (e.g., db.t3.micro)"
  default     = "db.t3.micro"
}
```

### 3. Provide useful outputs

```
output "database_connection_string" {
  description = "Connection string for the database"
  value       = "postgresql://${aws_db_instance.main.endpoint}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}"
}
```

### 4. Use locals for complex logic

```
locals {
  environment_config = {
    dev  = { instance_type = "t2.micro", backup_retention = 7 }
    prod = { instance_type = "t3.large", backup_retention = 30 }
  }
  
  current_config = local.environment_config[var.environment]
}
```

## Organizing Your Module Files

Here's a good structure for organizing modules:

```
terraform-project/
├── main.tf                    # Your main configuration
├── variables.tf               # Your main variables
├── outputs.tf                 # Your main outputs
├── terraform.tfvars          # Your variable values
└── modules/
    ├── web-server/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md          # Explain how to use the module
    ├── database/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── networking/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

**File naming conventions:**

- `main.tf` – main resources
- `variables.tf` – input variables
- `outputs.tf` – output values
- `versions.tf` – provider requirements (optional)
- `README.md` – documentation (highly recommended)

## Quick Module Checklist

When creating a module, ask yourself:

- ✅ **Purpose**: Does this module have a clear, single purpose?
- ✅ **Variables**: Are all the variables well-named and documented?
- ✅ **Outputs**: Does it output useful information for other modules?
- ✅ **Defaults**: Do variables have sensible default values?
- ✅ **Documentation**: Would someone else understand how to use this?
- ✅ **Testing**: Have you tested it with different input values?

## Common Module Patterns

### Pattern 1: Feature Toggles

```
variable "enable_monitoring" {
  type    = bool
  default = false
}

variable "enable_backups" {
  type    = bool
  default = false
}

# Only create monitoring resources if enabled
resource "local_file" "monitoring_config" {
  count = var.enable_monitoring ? 1 : 0
  
  filename = "monitoring.conf"
  content  = "Monitoring enabled"
}
```

### Pattern 2: Environment-Specific Configs

```
variable "environment" {
  type = string
}

locals {
  env_configs = {
    dev  = { size = "small", replicas = 1 }
    prod = { size = "large", replicas = 3 }
  }
  
  config = local.env_configs[var.environment]
}
```

### Pattern 3: Flexible Resource Creation

```
variable "additional_files" {
  type    = map(string)
  default = {}
}

resource "local_file" "extra_files" {
  for_each = var.additional_files
  
  filename = each.key
  content  = each.value
}
```

## What's Next?

Congratulations! You've learned how to build reusable infrastructure components:

### Module Basics – Packaging code for reuse:

- ✅ Creating your first module
- ✅ Module inputs (variables) and outputs
- ✅ Using modules in your main configuration
- ✅ Organizing module files properly

### Advanced Module Usage:

- ✅ Using modules from Terraform Registry
- ✅ Passing data between modules
- ✅ Module best practices and patterns
- ✅ File organization and documentation

### Real-World Applications:

- ✅ Building flexible, configurable modules
- ✅ Environment-specific configurations
- ✅ Feature toggles and conditional resources
- ✅ Complex data transformations in modules