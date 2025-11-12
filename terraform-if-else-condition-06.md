# Terraform If/Else Conditions: Making Smart Decisions

Terraform provides conditional statement-type logic using Ternary Operators and there is so much you can do with it.

## If/Else Statement Syntax in Terraform

```    
condition ? true_val : false_val
```

The above statement means if the given condition is true, use `true_val` else use `false_val`

Let's take the below example of creating VPC network in Google Cloud:

```    
locals {
  use_local_name = false
  name           = "main-vpc"
}

resource "google_compute_network" "base-vpc" {
  name                    = local.use_local_name ? local.name : "base-vpc"
  auto_create_subnetworks = false
}
```

In the above example, I am checking if the local variable `use_local_name` is true. If the condition is met then use the `local.name` as the name of the VPC, else use the name `"base-vpc"`.

Let me show where we can use this If/Else conditional logic to make our terraform code more flexible.

## Conditional Attribute Assignment

```    
resource "aws_instance" "example" {
  instance_type = var.environment == "production" ? "t2.large" : "t2.micro"
  # Additional resource configuration
}
```

In the above example, we can define the instance type to use as per the environment type while creating an AWS instance. If it's production, use `"t2.large"` else use `"t2.micro"`.

## To Replace Invalid Values

```    
variable "namespace" {
  type = string
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace != "" ? var.namespace : "my-namespace"
  }
}
```

In the above example, we check if the value provided for the variable namespace is an empty string. If it is, then it will assume the value `"my-namespace"`.

## Dynamic Resource Creation

Suppose you want to create an AWS instance only when it is explicitly told to do so. We can use the meta argument `count` with conditional logic as below:

You can think about it this way: you can set count to 1 on a specific resource and get one copy of that resource. If it's set to 0 then no resource will be created.

```    
variable "create_instances" {
  type    = bool
  default = false
}

resource "aws_instance" "example" {
  count = var.create_instances ? 1 : 0

  # Instance configuration
}
```

If you set the value for variable `create_instances` to true, the count value will be set to 1 and one copy of the AWS instance will be created.

If you will not set any value, or set the value as false, then the value for variable `create_instances` will be false and no AWS instance will be created.

## With Dynamic Block

The dynamic block allows you to generate multiple blocks of configuration dynamically based on a list or map variable.

We can combine Terraform's dynamic blocks with if/else conditions to create more complex configurations.

Let's take an example where we want to configure firewall logging when it is explicitly asked for using variable `ingress_tcp_log_enabled`:

```    
variable "ingress_tcp_log_enabled" {
  type    = bool
  default = false
}

resource "google_compute_firewall" "ingress-tcp" {
  project = var.project_id
  network = var.network

  name = "${var.prefix}-ingress-allow-tcp"

  allow {
    protocol = "tcp"
    ports    = var.tcp_ports
  }

  dynamic "log_config" {
    for_each = var.ingress_tcp_log_enabled ? ["enable-logs"] : []
    content {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }

  source_ranges = var.cidr_tcp
}
```

Or we can use it to dynamically create tags:

```    
dynamic "tag" {
  for_each = var.create_tags ? var.tags : []
  #             Condition     true_val   false_val  
  content {
    key   = tag.key
    value = tag.value
  }
}
```

## Type Conversion in Conditional Expressions

**Note:** In conditional expression, the two result types can be of any type, let's say one is number and other is string:

```    
var.network_name ? 1000 : "base-vpc"
```

Terraform will attempt to find a type in which it can convert both results. In this case it will convert both to string:

```    
var.network_name ? "1000" : "base-vpc"
```

It can often cause confusion. To avoid this, it is recommended to write specific conversion function as below:

```    
var.network_name ? tostring(1000) : "base-vpc"
```

## Practical Examples

### Environment-Based Configuration

```    
variable "environment" {
  type    = string
  default = "dev"
}

resource "aws_s3_bucket" "app_bucket" {
  bucket = "my-app-${var.environment}-bucket"
  
  # Enable versioning only in production
  versioning {
    enabled = var.environment == "production" ? true : false
  }
}

# Create backup bucket only in production
resource "aws_s3_bucket" "backup_bucket" {
  count  = var.environment == "production" ? 1 : 0
  bucket = "my-app-${var.environment}-backup-bucket"
}
```

### Multiple Conditions

```    
variable "environment" {
  type = string
}

variable "enable_monitoring" {
  type    = bool
  default = false
}

locals {
  # Complex condition combining multiple variables
  instance_type = var.environment == "production" ? "t3.large" : 
                  var.environment == "staging" ? "t3.medium" : "t2.micro"
  
  # Monitoring enabled for production or when explicitly requested
  monitoring_enabled = var.environment == "production" || var.enable_monitoring
}

resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = local.instance_type
  
  monitoring = local.monitoring_enabled
  
  tags = {
    Name        = "web-server"
    Environment = var.environment
    Monitoring  = local.monitoring_enabled ? "enabled" : "disabled"
  }
}
```

### Conditional Resource Blocks

```    
variable "enable_ssl" {
  type    = bool
  default = false
}

variable "ssl_certificate_arn" {
  type    = string
  default = ""
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.enable_ssl ? "443" : "80"
  protocol          = var.enable_ssl ? "HTTPS" : "HTTP"

  # SSL certificate block only when SSL is enabled
  dynamic "certificate" {
    for_each = var.enable_ssl && var.ssl_certificate_arn != "" ? [1] : []
    content {
      certificate_arn = var.ssl_certificate_arn
    }
  }

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
```

## Quick Reference

### Basic Ternary Operator:
```    
condition ? value_if_true : value_if_false
```

### Common Conditions:
```    
# String comparison
var.environment == "production" ? "large" : "small"

# Boolean check
var.enable_feature ? "enabled" : "disabled"

# Null/empty check
var.custom_name != "" ? var.custom_name : "default-name"

# Number comparison
var.instance_count > 1 ? "cluster" : "single"
```

### With Count:
```    
count = var.create_resource ? 1 : 0
```

### With For_Each:
```    
for_each = var.enable_feature ? var.feature_config : {}
```

### With Dynamic Blocks:
```    
dynamic "block_name" {
  for_each = var.condition ? [1] : []
  content {
    # block configuration
  }
}
```

## Best Practices

1. **Keep conditions simple and readable**
2. **Use locals for complex conditional logic**
3. **Be explicit with type conversions**
4. **Document complex conditions with comments**
5. **Test different condition scenarios**

## What's Next?

Excellent! You now understand how to make your Terraform code smart and flexible with conditional logic:

✅ **Ternary operators** – basic if/else syntax  
✅ **Conditional resource creation** – using count with conditions  
✅ **Dynamic blocks** – conditional configuration blocks  
✅ **Type handling** – managing different data types in conditions  
✅ **Real-world examples** – practical conditional patterns  

In our next post, we'll explore **Terraform Functions** – the built-in functions that help you manipulate strings, numbers, lists, and maps to create even more powerful and flexible infrastructure code!