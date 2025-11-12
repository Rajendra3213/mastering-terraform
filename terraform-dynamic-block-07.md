# Terraform Dynamic Blocks: Making Resources Super Flexible

Today, we're going to learn about dynamic blocks – a way to make the inside of your resources super flexible.

Think of it this way: `count` and `for_each` help you create multiple houses, but dynamic blocks help you add multiple rooms to each house!

## The Problem: Repeating Configuration Inside Resources

Let's say you want to create a security group (like a firewall) that allows multiple ports. The old way would be:

```   
resource "aws_security_group" "web" {
  name = "web-server"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

See how we're repeating the same ingress block over and over? That's a lot of typing! And what if you need to allow 10 ports? Or 20?

## Enter Dynamic Blocks

Dynamic blocks let you create multiple nested blocks inside a resource without repeating yourself.

Here's the magic version:

```   
variable "allowed_ports" {
  type    = list(number)
  default = [80, 443, 22]
}

resource "aws_security_group" "web" {
  name = "web-server"
  
  dynamic "ingress" {
    for_each = var.allowed_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}
```

**What just happened?**
- `dynamic "ingress"` creates multiple ingress blocks
- `for_each = var.allowed_ports` loops through the list of ports
- `content { }` defines what goes inside each ingress block
- `ingress.value` gets the current port number

This creates the exact same security group but with much less code!

## Understanding Dynamic Block Parts

Let's break down the parts of a dynamic block:

```   
dynamic "BLOCK_NAME" {
  for_each = LIST_OR_MAP
  content {
    # What goes inside each block
  }
}
```

**The parts:**
- `dynamic "BLOCK_NAME"` – what type of block to create (like "ingress", "tag", etc.)
- `for_each` – what to loop through
- `content` – the template for each block

## Your First Simple Dynamic Block

Let's start with something super simple – creating multiple configuration sections:

```   
variable "folder_info" {
  type = list(object({
    name = string
    size = string
  }))
  default = [
    { name = "documents", size = "500MB" },
    { name = "photos", size = "2GB" },
    { name = "videos", size = "10GB" }
  ]
}

resource "local_file" "backup_report" {
  filename = "backup-report.txt"
  content = <<-EOF
    Backup Report
    =============
    
    Folders to backup:
    %{for folder in var.folder_info}
    - ${folder.name}: ${folder.size}
    %{endfor}
    
    Total folders: ${length(var.folder_info)}
  EOF
}
```

**What's `%{for ... %{endfor}`?** This is Terraform's template syntax for loops inside strings. It's like a mini dynamic block for text!

## Real Dynamic Blocks with AWS

Let's use a real example with AWS security groups:

```   
variable "web_ports" {
  type = list(object({
    port        = number
    description = string
  }))
  default = [
    { port = 80, description = "HTTP traffic" },
    { port = 443, description = "HTTPS traffic" },
    { port = 22, description = "SSH access" }
  ]
}

resource "aws_security_group" "web_server" {
  name        = "web-server-sg"
  description = "Security group for web server"
  
  dynamic "ingress" {
    for_each = var.web_ports
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = ingress.value.description
    }
  }
  
  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "web-server-security-group"
  }
}
```

This creates a security group with 3 ingress rules, each with its own port and description!

## Dynamic Blocks with Different Data

Let's try something more complex – creating multiple disk attachments:

```   
variable "extra_disks" {
  type = list(object({
    device_name = string
    volume_type = string
    volume_size = number
    encrypted   = bool
  }))
  default = [
    {
      device_name = "/dev/sdb"
      volume_type = "gp3"
      volume_size = 100
      encrypted   = true
    },
    {
      device_name = "/dev/sdc" 
      volume_type = "gp3"
      volume_size = 200
      encrypted   = true
    }
  ]
}

resource "aws_instance" "web_server" {
  ami           = "ami-12345678"
  instance_type = "t3.medium"
  
  dynamic "ebs_block_device" {
    for_each = var.extra_disks
    content {
      device_name = ebs_block_device.value.device_name
      volume_type = ebs_block_device.value.volume_type
      volume_size = ebs_block_device.value.volume_size
      encrypted   = ebs_block_device.value.encrypted
    }
  }
  
  tags = {
    Name = "web-server-with-extra-disks"
  }
}
```

**What's happening:**
- `dynamic "ebs_block_device"` creates multiple disk attachments
- Each disk gets its own device name, type, size, and encryption setting
- `ebs_block_device.value.device_name` gets the device name from the current disk

## Using the Iterator Name

By default, you reference values with the block name (like `ingress.value` or `ebs_block_device.value`). But you can choose your own name:

```   
variable "network_rules" {
  type = list(object({
    port     = number
    protocol = string
    source   = string
  }))
  default = [
    { port = 80, protocol = "tcp", source = "0.0.0.0/0" },
    { port = 443, protocol = "tcp", source = "0.0.0.0/0" },
    { port = 3306, protocol = "tcp", source = "10.0.0.0/8" }
  ]
}

resource "aws_security_group" "database" {
  name = "database-sg"
  
  dynamic "ingress" {
    for_each = var.network_rules
    iterator = rule  # Custom name instead of "ingress"
    
    content {
      from_port   = rule.value.port
      to_port     = rule.value.port
      protocol    = rule.value.protocol
      cidr_blocks = [rule.value.source]
      description = "Allow ${rule.value.protocol} on port ${rule.value.port}"
    }
  }
}
```

Now you use `rule.value` instead of `ingress.value`. This makes the code easier to read!

## Conditional Dynamic Blocks

Sometimes you only want to create blocks under certain conditions:

```   
variable "environment" {
  type    = string
  default = "dev"
}

variable "monitoring_enabled" {
  type    = bool
  default = false
}

variable "backup_schedules" {
  type = list(object({
    name = string
    time = string
  }))
  default = [
    { name = "daily", time = "02:00" },
    { name = "weekly", time = "03:00" }
  ]
}

resource "local_file" "server_config" {
  filename = "${var.environment}-server.conf"
  content = <<-EOF
    # Server Configuration for ${var.environment}
    
    environment = ${var.environment}
    monitoring_enabled = ${var.monitoring_enabled}
    
    %{if var.monitoring_enabled}
    # Monitoring Configuration
    monitoring {
      enabled = true
      level = "${var.environment == "prod" ? "detailed" : "basic"}"
    }
    %{endif}
    
    %{if length(var.backup_schedules) > 0}
    # Backup Schedules
    %{for schedule in var.backup_schedules}
    backup "${schedule.name}" {
      time = "${schedule.time}"
      enabled = ${var.environment == "prod" ? "true" : "false"}
    }
    %{endfor}
    %{endif}
  EOF
}
```

**What's new:**
- `%{if condition}` only includes content if condition is true
- `%{for item in list}` loops through items
- You can use conditions inside the loops too

## Nested Dynamic Blocks

You can even put dynamic blocks inside other dynamic blocks! (But don't go crazy with this):

```   
variable "applications" {
  type = map(object({
    ports = list(object({
      number      = number
      protocol    = string
      description = string
    }))
    environment_vars = map(string)
  }))
  default = {
    web = {
      ports = [
        { number = 80, protocol = "tcp", description = "HTTP" },
        { number = 443, protocol = "tcp", description = "HTTPS" }
      ]
      environment_vars = {
        NODE_ENV = "production"
        PORT     = "3000"
      }
    }
    api = {
      ports = [
        { number = 8080, protocol = "tcp", description = "API" }
      ]
      environment_vars = {
        DATABASE_URL = "postgresql://localhost:5432/api"
        JWT_SECRET   = "super-secret"
      }
    }
  }
}

resource "local_file" "app_configs" {
  for_each = var.applications
  filename = "${each.key}-config.yaml"
  content = <<-EOF
    # Configuration for ${each.key} application
    
    name: ${each.key}
    
    ports:
    %{for port in each.value.ports}
      - number: ${port.number}
        protocol: ${port.protocol}
        description: ${port.description}
    %{endfor}
    
    environment:
    %{for key, value in each.value.environment_vars}
      ${key}: ${value}
    %{endfor}
  EOF
}
```

This creates separate config files for each application with their specific ports and environment variables!

## Practical Example: Complete Infrastructure Setup

Let's build something real – a complete web application setup:

```   
variable "app_config" {
  type = object({
    name         = string
    environment  = string
    ports        = list(number)
    ssl_enabled  = bool
    backup_files = list(string)
    team_access  = map(string)
  })
  default = {
    name         = "blogapp"
    environment  = "production"
    ports        = [80, 443, 22]
    ssl_enabled  = true
    backup_files = ["database", "uploads", "config"]
    team_access = {
      developers = "read-write"
      devops     = "admin"
      support    = "read-only"
    }
  }
}

# Create security group with dynamic rules
resource "local_file" "security_rules" {
  filename = "${var.app_config.name}-security.tf"
  content = <<-EOF
    # Security configuration for ${var.app_config.name}
    
    resource "aws_security_group" "${var.app_config.name}_sg" {
      name = "${var.app_config.name}-${var.app_config.environment}-sg"
      
    %{for port in var.app_config.ports}
      ingress {
        from_port   = ${port}
        to_port     = ${port}
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "Allow port ${port}"
      }
    %{endfor}
      
      egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
      }
    }
  EOF
}

# Create backup configuration
resource "local_file" "backup_config" {
  filename = "${var.app_config.name}-backup.json"
  content = jsonencode({
    application = var.app_config.name
    environment = var.app_config.environment
    backup_enabled = var.app_config.environment == "production"
    backup_items = [
      for file in var.app_config.backup_files : {
        name = file
        path = "/app/data/${file}"
        frequency = var.app_config.environment == "production" ? "hourly" : "daily"
      }
    ]
  })
}

# Create team access configuration
resource "local_file" "team_access" {
  filename = "${var.app_config.name}-access.yaml"
  content = <<-EOF
    # Team access configuration for ${var.app_config.name}
    
    application: ${var.app_config.name}
    environment: ${var.app_config.environment}
    
    team_permissions:
    %{for team, permission in var.app_config.team_access}
      ${team}:
        level: ${permission}
        ssl_required: ${var.app_config.ssl_enabled}
    %{endfor}
  EOF
}

# Create application summary
resource "local_file" "app_summary" {
  filename = "${var.app_config.name}-summary.md"
  content = <<-EOF
    # ${var.app_config.name} Application Summary
    
    ## Basic Information
    - **Application**: ${var.app_config.name}
    - **Environment**: ${var.app_config.environment}
    - **SSL Enabled**: ${var.app_config.ssl_enabled}
    
    ## Network Configuration
    ### Allowed Ports
    %{for port in var.app_config.ports}
    - Port ${port}
    %{endfor}
    
    ## Backup Configuration
    ### Files to Backup
    %{for file in var.app_config.backup_files}
    - ${file}
    %{endfor}
    
    ## Team Access
    %{for team, permission in var.app_config.team_access}
    - **${team}**: ${permission} access
    %{endfor}
    
    ## Files Generated
    - Security rules: ${var.app_config.name}-security.tf
    - Backup config: ${var.app_config.name}-backup.json  
    - Access config: ${var.app_config.name}-access.yaml
    
    *Generated by Terraform on ${timestamp()}*
  EOF
}

output "application_summary" {
  value = {
    app_name     = var.app_config.name
    environment  = var.app_config.environment
    ports_count  = length(var.app_config.ports)
    backup_items = length(var.app_config.backup_files)
    teams        = length(var.app_config.team_access)
    ssl_enabled  = var.app_config.ssl_enabled
    files_created = [
      "${var.app_config.name}-security.tf",
      "${var.app_config.name}-backup.json",
      "${var.app_config.name}-access.yaml",
      "${var.app_config.name}-summary.md"
    ]
  }
}
```

This creates a complete application setup with:
- Security group configuration
- Backup settings
- Team access rules
- A nice summary document

## When to Use Dynamic Blocks

### Use Dynamic Blocks when:
- You need multiple similar nested blocks in a resource
- The number or content of blocks might change
- You want to avoid repeating the same configuration

**Good examples:**
- Security group rules (multiple ports)
- Server disk attachments (multiple disks)
- Load balancer listeners (multiple protocols)
- Database parameter groups (multiple settings)

### Don't use Dynamic Blocks when:
- You have just one or two blocks (not worth the complexity)
- The blocks are very different from each other
- You're creating multiple resources (use count/for_each instead)

## Common Patterns

### Pattern 1: Port Lists
```   
variable "ports" {
  default = [80, 443, 22]
}

dynamic "ingress" {
  for_each = var.ports
  content {
    from_port = ingress.value
    to_port   = ingress.value
    protocol  = "tcp"
  }
}
```

### Pattern 2: Complex Objects
```   
variable "rules" {
  type = list(object({
    port = number
    protocol = string
    source = string
  }))
}

dynamic "ingress" {
  for_each = var.rules
  iterator = rule
  content {
    from_port   = rule.value.port
    to_port     = rule.value.port
    protocol    = rule.value.protocol
    cidr_blocks = [rule.value.source]
  }
}
```

### Pattern 3: Conditional Blocks
```   
dynamic "backup" {
  for_each = var.enable_backup ? var.backup_configs : []
  content {
    # backup configuration
  }
}
```

## Quick Reference

### Basic Dynamic Block:
```   
dynamic "BLOCK_NAME" {
  for_each = LIST_OR_MAP
  content {
    # block configuration using BLOCK_NAME.value
  }
}
```

### With Custom Iterator:
```   
dynamic "BLOCK_NAME" {
  for_each = LIST_OR_MAP
  iterator = custom_name
  content {
    # block configuration using custom_name.value
  }
}
```

### Template Loops in Strings:
```   
content = <<-EOF
%{for item in var.list}
  - ${item}
%{endfor}
EOF
```

### Conditional Templates:
```   
content = <<-EOF
%{if var.condition}
  This appears when condition is true
%{endif}
EOF
```

## Practice Challenge

Try creating this yourself:
1. Create a variable with different database configurations (name, port, backup_enabled)
2. Use dynamic blocks to create multiple configuration sections
3. Use template loops to create a formatted report
4. Add conditional sections based on environment

Here's a starter:

```   
variable "databases" {
  type = list(object({
    name           = string
    port           = number
    backup_enabled = bool
    storage_size   = number
  }))
  default = [
    # Add your database configs here
  ]
}

# Your dynamic blocks here
```

## What's Next?

Fantastic work! You've mastered another powerful Terraform feature:

### Dynamic Blocks – Making resources super flexible:
✅ Creating multiple nested blocks without repetition  
✅ Using for_each with complex data structures  
✅ Custom iterators for cleaner code  
✅ Template loops and conditionals in strings  
✅ When and how to use dynamic blocks effectively  

### Advanced Patterns:
✅ Conditional dynamic blocks  
✅ Nested dynamic blocks  
✅ Complex configuration generation  
✅ Real-world application examples  

In our next post, we'll explore **Terraform Functions** – the built-in tools that help you manipulate data, format strings, work with lists and maps, and do calculations. You'll learn:

- String functions for text manipulation
- List and map functions for data processing
- Math functions for calculations
- Date and time functions
- How to combine functions for powerful data transformations

The dynamic block knowledge you gained today will work perfectly with functions to create incredibly flexible configurations!

Ready to supercharge your Terraform with built-in functions? The next post will show you some amazing data manipulation tricks!