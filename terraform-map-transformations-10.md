# Terraform Map Transformations - Advanced Data Manipulation

Map transformations in Terraform are like having a Swiss Army knife for data manipulation. They let you reshape, filter, and transform your data structures to fit exactly what your infrastructure needs.

## Why Map Transformations Matter

Think of map transformations as your data processing pipeline. Instead of writing repetitive code for similar resources, you define the data once and transform it into the exact shape you need for different resources.

**The Problem Without Transformations:**
```
# Repetitive and hard to maintain
resource "aws_lambda_function" "function1" {
  function_name = "function1"
  # ... configuration
}

resource "aws_lambda_function" "function2" {
  function_name = "function2"
  # ... same configuration
}

resource "aws_lambda_function" "function3" {
  function_name = "function3"
  # ... same configuration again
}
```

**The Solution With Transformations:**
```
locals {
  functions = {
    function1 = { runtime = "python3.9", timeout = 30 }
    function2 = { runtime = "nodejs18.x", timeout = 60 }
    function3 = { runtime = "python3.9", timeout = 45 }
  }
}

resource "aws_lambda_function" "functions" {
  for_each = local.functions
  
  function_name = each.key
  runtime      = each.value.runtime
  timeout      = each.value.timeout
}
```

## Basic Map Transformation Syntax

The basic syntax for map transformations uses the `for` expression:

```
{ for key, value in map : new_key => new_value }
```

**Simple Example:**
```
locals {
  original = {
    web    = "nginx"
    db     = "postgres"
    cache  = "redis"
  }
  
  # Transform to uppercase values
  uppercase = { for k, v in local.original : k => upper(v) }
  # Result: { web = "NGINX", db = "POSTGRES", cache = "REDIS" }
}
```

## Real-World Example 1: Lambda Functions with S3 Triggers

Let's build a system where Lambda functions are triggered by S3 events:

```
locals {
  # Define our Lambda functions
  lambda_config = {
    image_processor = {
      runtime     = "python3.9"
      timeout     = 300
      memory_size = 512
      s3_bucket   = "images-bucket"
      s3_events   = ["s3:ObjectCreated:*"]
    }
    log_analyzer = {
      runtime     = "nodejs18.x"
      timeout     = 60
      memory_size = 256
      s3_bucket   = "logs-bucket"
      s3_events   = ["s3:ObjectCreated:Put"]
    }
    backup_processor = {
      runtime     = "python3.9"
      timeout     = 900
      memory_size = 1024
      s3_bucket   = "backup-bucket"
      s3_events   = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    }
  }
  
  # Transform for S3 triggers - only functions that have S3 configuration
  s3_triggers = {
    for name, config in local.lambda_config : 
    name => config 
    if lookup(config, "s3_bucket", null) != null
  }
}

# Create Lambda functions
resource "aws_lambda_function" "functions" {
  for_each = local.lambda_config
  
  function_name = each.key
  runtime      = each.value.runtime
  timeout      = each.value.timeout
  memory_size  = each.value.memory_size
  
  filename         = "${each.key}.zip"
  source_code_hash = filebase64sha256("${each.key}.zip")
  handler         = "index.handler"
  role           = aws_iam_role.lambda_role.arn
}

# Create S3 bucket notifications
resource "aws_s3_bucket_notification" "bucket_notification" {
  for_each = local.s3_triggers
  
  bucket = each.value.s3_bucket
  
  lambda_function {
    lambda_function_arn = aws_lambda_function.functions[each.key].arn
    events             = each.value.s3_events
  }
}

# Grant S3 permission to invoke Lambda
resource "aws_lambda_permission" "allow_bucket" {
  for_each = local.s3_triggers
  
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.functions[each.key].arn
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${each.value.bucket}"
}
```

## Real-World Example 2: Lambda Layers with Cross-Account Permissions

Building Lambda layers that can be shared across multiple AWS accounts:

```
# config.tf
locals {
  layer_definitions = [
    {
      identifier          = "layer1"
      description        = "Contains some python packages"
      path              = "layers/layer1"
      compatible_runtimes = ["python3.8", "python3.9", "python3.10", "python3.11"]
    },
    {
      identifier          = "layer2"
      description        = "Contains some python packages"
      path              = "layers/layer2"
      compatible_runtimes = ["python3.8", "python3.9", "python3.10", "python3.11"]
    }
  ]
  
  # Transform list to map for for_each
  layers_info = { for i in local.layer_definitions : i.identifier => i }
  
  # Extract layer names
  layer_names = [for i in local.layer_definitions : i.identifier]
  
  # Accounts that should have permission on layer version
  allowed_accounts = ["123456789012", "987654321098"]
  
  # Create combinations of layers and accounts
  layers_to_accounts = flatten([
    for layer in local.layer_names : [
      for account in local.allowed_accounts : {
        id      = "${layer}-${account}"
        layer   = layer
        account = account
      }
    ]
  ])
  
  # Convert to map for for_each
  layers_to_accounts_map = { for item in local.layers_to_accounts : item.id => item }
}

# Create Lambda layers
module "layers" {
  for_each = local.layers_info
  source   = "terraform-aws-modules/lambda/aws"
  version  = "7.7.0"
  
  create_layer = true
  layer_name   = each.key
  description  = each.value.description
  
  source_path = [
    {
      path             = "${path.module}/${each.value.path}"
      pip_requirements = true
      prefix_in_zip    = "python"
    }
  ]
  
  compatible_runtimes      = each.value.compatible_runtimes
  compatible_architectures = ["x86_64"]
  store_on_s3             = true
  s3_prefix               = "layers/${each.key}"
  s3_bucket               = aws_s3_bucket.lambda_artifacts.id
}

# Grant cross-account permissions
resource "aws_lambda_layer_version_permission" "lambda_layer_permission" {
  for_each = local.layers_to_accounts_map
  
  layer_name     = module.layers[each.value.layer].lambda_layer_layer_arn
  version_number = module.layers[each.value.layer].lambda_layer_version
  principal      = each.value.account
  action         = "lambda:GetLayerVersion"
  statement_id   = "${each.value.layer}-${each.value.account}-${random_integer.random.result}"
}

resource "random_integer" "random" {
  min = 1
  max = 1000
}
```

## Common Map Transformation Patterns

### 1. Copying Maps

Create independent copies of maps:

```
locals {
  original_map = {
    key1 = "value1"
    key2 = "value2"
    key3 = "value3"
  }
  
  cloned_map = { for k, v in local.original_map : k => v }
}
```

### 2. Map Filtering

Filter elements based on conditions:

```
locals {
  original_map = {
    apple  = 5
    banana = 3
    orange = 7
    pear   = 2
  }
  
  # Only fruits with quantity > 3
  filtered_map = { for k, v in local.original_map : k => v if v > 3 }
  # Result: { apple = 5, orange = 7 }
}
```

### 3. Map Subsetting

Create smaller maps with specific keys:

```
locals {
  full_map = {
    a = 1
    b = 2
    c = 3
    d = 4
  }
  
  subset_map_keys = ["a", "c"]
  subset_map = { for k, v in local.full_map : k => v if contains(local.subset_map_keys, k) }
  # Result: { a = 1, c = 3 }
}
```

### 4. Data Transformation

Transform keys and values:

```
locals {
  raw_data = {
    name     = "John Doe"
    age      = "30"
    location = "City"
  }
  
  transformed_data = {
    for key, value in local.raw_data : 
    key == "name" ? "full_name" : 
    key == "age" ? "years_old" : 
    key == "location" ? "city" : key => value
  }
  # Result: { full_name = "John Doe", years_old = "30", city = "City" }
}
```

### 5. Generating Resource Configurations

Create multiple similar configurations:

```
locals {
  resource_settings = {
    web = { port = 80, protocol = "http" }
    db  = { port = 3306, protocol = "mysql" }
  }
  
  resource_instances = flatten([
    for name, settings in local.resource_settings : [
      for i in range(2) : {
        name     = "${name}-${i}"
        port     = settings.port
        protocol = settings.protocol
      }
    ]
  ])
}
```

### 6. Creating Tags and Labels

Generate consistent tagging:

```
locals {
  resource_names = ["instance1", "instance2", "instance3"]
  
  resource_labels = {
    for name in local.resource_names : name => {
      Name        = name
      Environment = "production"
      ManagedBy   = "terraform"
    }
  }
}
```

### 7. Configuration Composition

Merge base configurations with overrides:

```
locals {
  base_config = {
    region      = "us-west-1"
    environment = "production"
  }
  
  module_overrides = {
    instance1 = {
      region        = "us-east-1"
      instance_type = "t2.micro"
    }
    instance2 = {
      environment   = "development"
      instance_type = "t2.nano"
    }
  }
  
  final_config = {
    for name, config in local.module_overrides : 
    name => merge(local.base_config, config)
  }
}
```

## List Transformations

Transform maps into lists and vice versa:

### Extract Keys or Values

```
locals {
  aws_bucket_names = {
    name1 = "bucket1"
    name2 = "bucket2"
    name3 = "bucket3"
  }
  
  # Extract keys
  bucket_name_list = [for name, _ in local.aws_bucket_names : name]
  # Result: ["name1", "name2", "name3"]
  
  # Extract values
  bucket_values = [for _, bucket in local.aws_bucket_names : bucket]
  # Result: ["bucket1", "bucket2", "bucket3"]
}
```

### Case Conversion

```
locals {
  services = ["web", "api", "database"]
  
  # Convert to uppercase
  uppercase_services = [for s in local.services : upper(s)]
  # Result: ["WEB", "API", "DATABASE"]
}
```

### Conditional List Creation

```
locals {
  all_services = ["web", "api", "", "database", "cache"]
  
  # Filter out empty strings
  valid_services = [for s in local.all_services : upper(s) if s != ""]
  # Result: ["WEB", "API", "DATABASE", "CACHE"]
}
```

## Advanced Transformation Techniques

### Nested Transformations

```
locals {
  environments = {
    dev = {
      services = {
        web = { replicas = 1, memory = "512Mi" }
        api = { replicas = 1, memory = "256Mi" }
      }
    }
    prod = {
      services = {
        web = { replicas = 3, memory = "1Gi" }
        api = { replicas = 2, memory = "512Mi" }
      }
    }
  }
  
  # Flatten all services across environments
  all_services = flatten([
    for env_name, env_config in local.environments : [
      for service_name, service_config in env_config.services : {
        key         = "${env_name}-${service_name}"
        environment = env_name
        service     = service_name
        replicas    = service_config.replicas
        memory      = service_config.memory
      }
    ]
  ])
  
  # Convert back to map for for_each
  services_map = { for service in local.all_services : service.key => service }
}
```

### Complex Filtering and Grouping

```
locals {
  servers = {
    web1    = { type = "web", region = "us-east-1", size = "large" }
    web2    = { type = "web", region = "us-west-1", size = "medium" }
    db1     = { type = "database", region = "us-east-1", size = "xlarge" }
    db2     = { type = "database", region = "us-west-1", size = "large" }
    cache1  = { type = "cache", region = "us-east-1", size = "small" }
  }
  
  # Group by region
  servers_by_region = {
    for region in distinct([for s in local.servers : s.region]) :
    region => {
      for name, config in local.servers : name => config
      if config.region == region
    }
  }
  
  # Filter large servers only
  large_servers = {
    for name, config in local.servers : name => config
    if contains(["large", "xlarge"], config.size)
  }
}
```

## Best Practices for Map Transformations

### 1. Keep Transformations Readable

```
# Good - clear and readable
locals {
  web_servers = {
    for name, config in local.all_servers : 
    name => config 
    if config.type == "web"
  }
}

# Avoid - too complex in one line
locals {
  complex_transform = { for k, v in local.data : k => merge(v, { new_field = v.field1 != null ? upper(v.field1) : "default" }) if v.enabled == true && contains(["prod", "staging"], v.env) }
}
```

### 2. Use Intermediate Variables

```
locals {
  # Step 1: Filter
  enabled_services = {
    for name, config in local.all_services : 
    name => config 
    if config.enabled
  }
  
  # Step 2: Transform
  service_configs = {
    for name, config in local.enabled_services : 
    name => {
      image = "${config.image}:${config.version}"
      port  = config.port
      env   = config.environment
    }
  }
}
```

### 3. Document Complex Transformations

```
locals {
  # Create a mapping of Lambda functions to their S3 triggers
  # This allows us to create S3 bucket notifications only for functions
  # that actually need to be triggered by S3 events
  s3_triggered_functions = {
    for name, config in local.lambda_functions : 
    name => {
      bucket_name = config.s3_bucket
      events      = config.s3_events
      function_arn = aws_lambda_function.functions[name].arn
    }
    if lookup(config, "s3_bucket", null) != null
  }
}
```

## Common Pitfalls and Solutions

### 1. Null Values in Transformations

```
# Problem: null values cause errors
locals {
  servers = {
    web1 = { name = "web1", port = 80 }
    web2 = { name = "web2", port = null }  # This could cause issues
  }
}

# Solution: Handle nulls explicitly
locals {
  server_ports = {
    for name, config in local.servers : 
    name => config.port != null ? config.port : 8080
  }
}
```

### 2. Empty Collections

```
# Problem: Empty maps/lists in transformations
locals {
  empty_map = {}
  
  # This works but produces empty result
  transformed = { for k, v in local.empty_map : k => v }
}

# Solution: Provide defaults or check for emptiness
locals {
  safe_transform = length(local.empty_map) > 0 ? {
    for k, v in local.empty_map : k => v
  } : { default = "no_data" }
}
```

## Performance Considerations

### 1. Avoid Nested Loops When Possible

```
# Less efficient - nested loops
locals {
  combinations = flatten([
    for env in local.environments : [
      for service in local.services : [
        for region in local.regions : {
          key = "${env}-${service}-${region}"
          # ... config
        }
      ]
    ]
  ])
}

# More efficient - single loop with logic
locals {
  combinations = [
    for combo in setproduct(local.environments, local.services, local.regions) : {
      key = join("-", combo)
      env = combo[0]
      service = combo[1]
      region = combo[2]
    }
  ]
}
```

### 2. Use Appropriate Data Structures

```
# For lookups, use maps
locals {
  server_configs = {
    web = { port = 80 }
    api = { port = 8080 }
  }
}

# For iteration, use lists
locals {
  server_names = ["web", "api", "database"]
}
```

## What's Next?

You've learned how to transform and manipulate data structures in Terraform:

### Core Concepts:
- ✅ Basic map transformation syntax
- ✅ Filtering and subsetting data
- ✅ Converting between maps and lists
- ✅ Complex nested transformations

### Real-World Applications:
- ✅ Lambda functions with S3 triggers
- ✅ Cross-account resource permissions
- ✅ Dynamic resource configuration
- ✅ Tag and label generation

### Best Practices:
- ✅ Readable transformation code
- ✅ Error handling and null safety
- ✅ Performance optimization
- ✅ Documentation and maintainability

Map transformations are the key to writing flexible, maintainable Terraform code that scales with your infrastructure needs!