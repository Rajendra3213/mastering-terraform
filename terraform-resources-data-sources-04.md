# Terraform Resources and Data Sources: Building Infrastructure

## Understanding Resources vs Data Sources

**Resources** create and manage infrastructure - they're the things Terraform builds for you.  
**Data Sources** read information about existing infrastructure - they're like asking "what's already there?"

## Your First Real Resource: EC2 Instance

Let's create a web server on AWS:

```   
provider "aws" {
  region = "us-west-2"
}

# Data source: Find the latest Amazon Linux AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Resource: Security group (firewall rules)
resource "aws_security_group" "web" {
  name        = "terraform-web-sg"
  description = "Security group for web server"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Resource: EC2 instance
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web.id]
  
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello from Terraform!</h1>" > /var/www/html/index.html
  EOF
  
  tags = {
    Name = "terraform-web-server"
  }
}

# Output server information
output "web_server_info" {
  value = {
    instance_id = aws_instance.web.id
    public_ip   = aws_instance.web.public_ip
    ami_used    = data.aws_ami.amazon_linux.id
    ami_name    = data.aws_ami.amazon_linux.name
  }
}
```

**Key concepts:**
- `data "aws_ami"` – finds the latest Amazon Linux image
- `filter` block – searches for specific criteria
- `most_recent = true` – gets the newest match
- `user_data` – script that runs when the server starts
- `vpc_security_group_ids` – attaches security group to server

## Dependencies Between Resources

Terraform automatically figures out the order to create things based on references:

```   
# 1. This gets created first (no dependencies)
resource "aws_s3_bucket" "app_bucket" {
  bucket = "my-app-bucket-12345"
}

# 2. This gets created second (depends on bucket)
resource "aws_s3_object" "config" {
  bucket = aws_s3_bucket.app_bucket.bucket  # Depends on bucket
  key    = "config.json"
  content = jsonencode({
    app_name = "MyApp"
    version  = "1.0"
  })
}

# 3. This gets created third (depends on both)
resource "local_file" "deployment_info" {
  filename = "deployment.txt"
  content = <<-EOF
    Bucket: ${aws_s3_bucket.app_bucket.bucket}
    Config File: ${aws_s3_object.config.key}
    Bucket Region: ${aws_s3_bucket.app_bucket.region}
  EOF
}
```

Terraform automatically creates them in the right order: bucket → file upload → local file.

## Explicit Dependencies

Sometimes you need to force an order that Terraform can't figure out:

```   
resource "aws_s3_bucket" "first" {
  bucket = "first-bucket-12345"
}

resource "aws_s3_bucket" "second" {
  bucket = "second-bucket-12345"
  
  # Force this to be created after the first bucket
  depends_on = [aws_s3_bucket.first]
}
```

**When to use `depends_on`:**
- When resources are related but don't directly reference each other
- When you need a specific creation order for business reasons
- Usually, you won't need this – Terraform is smart about dependencies

## Reading Provider Documentation

The best way to learn about resources is from the provider documentation. Let's walk through reading AWS provider docs:

1. **Step 1:** Go to registry.terraform.io
2. **Step 2:** Search for "aws"
3. **Step 3:** Click on the hashicorp/aws provider
4. **Step 4:** Look at the documentation for any resource

**What you'll find:**
- **Example Usage** – copy-paste examples
- **Argument Reference** – what you can configure
- **Attributes Reference** – what you can reference from other resources
- **Import** – how to import existing resources

For example, for `aws_s3_bucket`:
- **Arguments:** bucket, tags, etc.
- **Attributes:** id, arn, region, etc.

## Data Sources vs Resources: When to Use What

**Use Resources when:**
- Creating new infrastructure
- You want Terraform to manage the lifecycle
- You need to modify or delete things later

**Use Data Sources when:**
- Getting information about existing infrastructure
- Referencing things created outside Terraform
- Getting dynamic information (like latest AMI IDs)

## Practical Example: Complete Application Stack

Let's combine everything into a complete example:

```   
variable "app_name" {
  type        = string
  description = "Name of the application"
  default     = "mywebapp"
}

variable "environment" {
  type        = string
  description = "Environment (dev/prod)"
  default     = "dev"
}

provider "aws" {
  region = "us-west-2"
}

# Data source: Get latest AMI
data "aws_ami" "app_ami" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Data source: Get current AWS account info
data "aws_caller_identity" "current" {}

# Resource: Random suffix for unique names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Resource: S3 bucket for app data
resource "aws_s3_bucket" "app_data" {
  bucket = "${var.app_name}-${var.environment}-data-${random_string.suffix.result}"
}

# Resource: Security group
resource "aws_security_group" "app" {
  name        = "${var.app_name}-${var.environment}-sg"
  description = "Security group for ${var.app_name}"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Resource: EC2 instance
resource "aws_instance" "app" {
  ami                    = data.aws_ami.app_ami.id
  instance_type          = var.environment == "prod" ? "t3.medium" : "t2.micro"
  vpc_security_group_ids = [aws_security_group.app.id]
  
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd aws-cli
    systemctl start httpd
    systemctl enable httpd
    
    # Create a simple page with app info
    cat > /var/www/html/index.html << HTML
    <!DOCTYPE html>
    <html>
    <head><title>${var.app_name}</title></head>
    <body>
        <h1>${var.app_name} - ${var.environment}</h1>
        <p>Instance ID: \$(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
        <p>AMI ID: ${data.aws_ami.app_ami.id}</p>
        <p>Bucket: ${aws_s3_bucket.app_data.bucket}</p>
        <p>Account: ${data.aws_caller_identity.current.account_id}</p>
    </body>
    </html>
HTML
  EOF
  
  tags = {
    Name        = "${var.app_name}-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Resource: Upload a config file to S3
resource "aws_s3_object" "app_config" {
  bucket = aws_s3_bucket.app_data.bucket
  key    = "config/${var.environment}.json"
  content = jsonencode({
    app_name    = var.app_name
    environment = var.environment
    server_id   = aws_instance.app.id
    created_by  = "terraform"
    account_id  = data.aws_caller_identity.current.account_id
  })
}

# Outputs
output "application_info" {
  value = {
    app_name    = var.app_name
    environment = var.environment
    server_ip   = aws_instance.app.public_ip
    bucket_name = aws_s3_bucket.app_data.bucket
    ami_used    = data.aws_ami.app_ami.name
    config_file = "${aws_s3_bucket.app_data.bucket}/${aws_s3_object.app_config.key}"
  }
}

output "connection_info" {
  value = "Visit http://${aws_instance.app.public_ip} to see your app!"
}
```

Create a `terraform.tfvars` file to test different environments:

```   
app_name    = "blogapp"
environment = "dev"
```

## Understanding Resource Lifecycle

Resources go through different stages:

**Create:** When you first run `terraform apply`
```
+ aws_s3_bucket.example will be created
```

**Update:** When you change configuration
```
~ aws_s3_bucket.example will be updated in-place
```

**Destroy:** When you remove from config or run `terraform destroy`
```
- aws_s3_bucket.example will be destroyed
```

**Replace:** When changes can't be done in-place
```
-/+ aws_instance.web must be replaced
```

## Common Resource Patterns

### 1. Conditional Resources:
```   
resource "aws_s3_bucket" "backup" {
  count  = var.enable_backup ? 1 : 0
  bucket = "backup-bucket-12345"
}
```

### 2. Resource Naming:
```   
resource "aws_s3_bucket" "app" {
  bucket = "${var.app_name}-${var.environment}-${random_string.suffix.result}"
}
```

### 3. Tagging Strategy:
```   
resource "aws_instance" "web" {
  # ... other configuration ...
  
  tags = {
    Name        = "${var.app_name}-web"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    CreatedDate = timestamp()
  }
}
```

## Quick Reference

### Resource Syntax:
```   
resource "PROVIDER_TYPE" "NAME" {
  argument1 = "value1"
  argument2 = "value2"
}
```

### Data Source Syntax:
```   
data "PROVIDER_TYPE" "NAME" {
  filter_argument = "filter_value"
}
```

### Referencing:
```   
# Resource attributes
resource_type.resource_name.attribute

# Data source attributes  
data.data_source_type.data_source_name.attribute
```

### Common AWS Data Sources:
- `aws_ami` – Find AMI images
- `aws_caller_identity` – Current AWS account info
- `aws_region` – Current region info
- `aws_availability_zones` – Available AZs
- `aws_s3_bucket` – Existing S3 bucket info

### Common AWS Resources:
- `aws_instance` – EC2 servers
- `aws_s3_bucket` – S3 storage buckets
- `aws_security_group` – Firewall rules
- `aws_s3_object` – Files in S3

## What's Next?

Fantastic progress! You now understand the core building blocks of Terraform:

### Resources – Creating infrastructure:
✅ Resource syntax and naming patterns  
✅ Resource attributes and references  
✅ Dependencies between resources  
✅ Resource lifecycle management  

### Data Sources – Finding existing infrastructure:
✅ Data source syntax and usage  
✅ Finding existing resources  
✅ Getting dynamic information (AMIs, account info)  
✅ When to use data sources vs resources  

### Provider Documentation:
✅ How to read and use provider docs  
✅ Understanding arguments vs attributes  
✅ Finding examples and usage patterns  

In our next post, we'll explore **Terraform Modules** – how to create reusable infrastructure components that you can share and use across multiple projects. You'll learn to build your own infrastructure library!