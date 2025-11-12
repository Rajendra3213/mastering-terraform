# Terraform Count and For_Each: Creating Multiple Resources

Imagine you need to create 5 servers. Without what we're learning today, you'd have to write the same server code 5 times. That's like writing "I will not copy code" 100 times on a blackboard – boring and painful!

But with `count` and `for_each`, you can create 5 servers (or 50!) with almost the same amount of code as creating 1. Pretty magical, right?

## The Problem: Repeating Yourself

Let's say you want to create 3 files. The old way would be:

```     
resource "local_file" "file1" {
  content  = "This is file 1"
  filename = "file1.txt"
}

resource "local_file" "file2" {
  content  = "This is file 2"
  filename = "file2.txt"
}

resource "local_file" "file3" {
  content  = "This is file 3"
  filename = "file3.txt"
}
```

That's a lot of typing! And what if you need 10 files? Or 100? You'd be there all day!

## Enter Count: Your Copy Machine

Count is like having a copy machine that can make exactly the number of copies you want.

Here's the magic version:

```     
resource "local_file" "files" {
  count    = 3
  content  = "This is file ${count.index + 1}"
  filename = "file${count.index + 1}.txt"
}
```

That's it! This creates 3 files with just one resource block.

**What's happening here:**
- `count = 3` tells Terraform "make 3 of these"
- `count.index` is a special number that starts at 0, then 1, then 2
- `count.index + 1` gives us 1, 2, 3 (more human-friendly)

## Understanding Count.Index

Count.index is like a counter that Terraform uses:

- **First file:** count.index = 0 (so count.index + 1 = 1)
- **Second file:** count.index = 1 (so count.index + 1 = 2)
- **Third file:** count.index = 2 (so count.index + 1 = 3)

Let's see this in action:

```     
resource "local_file" "greeting" {
  count    = 4
  content  = "Hello! I am file number ${count.index + 1}"
  filename = "greeting-${count.index + 1}.txt"
}
```

This creates:
- `greeting-1.txt` with content "Hello! I am file number 1"
- `greeting-2.txt` with content "Hello! I am file number 2"
- `greeting-3.txt` with content "Hello! I am file number 3"
- `greeting-4.txt` with content "Hello! I am file number 4"

Try it! It's pretty cool to see Terraform create multiple files instantly.

## Count with Variables

You can use variables to control how many things you create:

```     
variable "how_many_servers" {
  type        = number
  description = "How many servers do you want?"
  default     = 2
}

resource "local_file" "server_config" {
  count    = var.how_many_servers
  content  = "Server ${count.index + 1} configuration"
  filename = "server-${count.index + 1}-config.txt"
}
```

Now you can change the number without editing your code:

```bash
terraform apply -var="how_many_servers=5"
```

Boom! 5 server config files created.

## Count with Lists

This is where it gets really useful. You can use count with lists:

```     
variable "server_names" {
  type    = list(string)
  default = ["web", "database", "cache"]
}

resource "local_file" "servers" {
  count    = length(var.server_names)
  content  = "Configuration for ${var.server_names[count.index]} server"
  filename = "${var.server_names[count.index]}-config.txt"
}
```

**What's new:**
- `length(var.server_names)` counts how many items in the list (3 in this case)
- `var.server_names[count.index]` gets the item at that position

This creates:
- `web-config.txt`
- `database-config.txt`
- `cache-config.txt`

## Conditional Creation with Count

Want to create something only sometimes? Count can do that too:

```     
variable "create_backup" {
  type    = bool
  default = false
}

resource "local_file" "backup_config" {
  count    = var.create_backup ? 1 : 0
  content  = "Backup configuration enabled"
  filename = "backup-config.txt"
}
```

**How this works:**
- If `create_backup` is true: count = 1 (creates 1 file)
- If `create_backup` is false: count = 0 (creates 0 files)

Try it both ways:

```bash
terraform apply -var="create_backup=true"
terraform apply -var="create_backup=false"
```

## Enter For_Each: The Smart Choice

While count is great, `for_each` is often smarter. Think of `for_each` as count's intelligent cousin.

Here's the same example with `for_each`:

```     
variable "servers" {
  type = map(string)
  default = {
    web   = "Web Server Config"
    db    = "Database Server Config"  
    cache = "Cache Server Config"
  }
}

resource "local_file" "server_configs" {
  for_each = var.servers
  content  = each.value
  filename = "${each.key}-config.txt"
}
```

**What's different:**
- `for_each = var.servers` loops through the map
- `each.key` is the left side ("web", "db", "cache")
- `each.value` is the right side ("Web Server Config", etc.)

This creates the same files but with a smarter approach.

## Why For_Each is Often Better

Let me show you why `for_each` is usually the better choice:

**With Count:** If you have servers `["web", "db", "cache"]` and you remove "db", Terraform gets confused:
- **Old:** web(0), db(1), cache(2)
- **New:** web(0), cache(1)
- Terraform thinks cache moved and recreates it!

**With For_Each:**
- **Old:** web("web"), db("db"), cache("cache")
- **New:** web("web"), cache("cache")
- Terraform just removes db, leaves cache alone

Smart, right?

## For_Each with Sets

You can use `for_each` with lists too, but you need to convert them to sets:

```     
variable "backup_folders" {
  type    = list(string)
  default = ["documents", "photos", "music"]
}

resource "local_file" "backup_info" {
  for_each = toset(var.backup_folders)
  content  = "Backup information for ${each.value} folder"
  filename = "${each.value}-backup-info.txt"
}
```

**What's `toset()`?** It converts a list to a set. For_each needs either a map or a set, not a list.

With sets, `each.key` and `each.value` are the same thing.

## Real World Example: Multiple Environments

Let's build something useful – configurations for different environments:

```     
variable "environments" {
  type = map(object({
    server_size = string
    backup_days = number
    ssl_enabled = bool
  }))
  default = {
    dev = {
      server_size = "small"
      backup_days = 7
      ssl_enabled = false
    }
    staging = {
      server_size = "medium"
      backup_days = 14
      ssl_enabled = true
    }
    prod = {
      server_size = "large"
      backup_days = 30
      ssl_enabled = true
    }
  }
}

resource "local_file" "env_config" {
  for_each = var.environments
  
  filename = "${each.key}-environment.json"
  content = jsonencode({
    environment = each.key
    server_size = each.value.server_size
    backup_days = each.value.backup_days
    ssl_enabled = each.value.ssl_enabled
    created_by  = "Terraform"
  })
}

output "environments_created" {
  value = {
    for env_name, config in local_file.env_config : 
    env_name => config.filename
  }
}
```

**What's new here:**
- `map(object({...}))` – a map where each value is an object with specific properties
- `jsonencode()` – converts the data to JSON format
- The output uses a for expression to show all created files

This creates three JSON files with environment-specific configurations!

## When to Use Count vs For_Each

### Use Count when:
- You need a specific number of identical things
- You're working with simple lists
- The order matters and won't change

```     
# Good use of count - creating 5 identical workers
resource "local_file" "workers" {
  count    = 5
  content  = "Worker ${count.index + 1} ready for tasks"
  filename = "worker-${count.index + 1}.txt"
}
```

### Use For_Each when:
- You need to create things with different configurations
- You might add/remove items later
- You want to reference specific instances by name

```     
# Good use of for_each - different server types
variable "server_types" {
  default = {
    web = "t2.micro"
    db  = "t2.small"  
    api = "t2.medium"
  }
}

resource "local_file" "server_specs" {
  for_each = var.server_types
  content  = "Server ${each.key} uses ${each.value} instance type"
  filename = "${each.key}-server-spec.txt"
}
```

## Practical Example: Website Components

Let's create a complete website setup:

```     
variable "website_components" {
  type = map(object({
    port        = number
    health_path = string
    replicas    = number
  }))
  default = {
    frontend = {
      port        = 3000
      health_path = "/health"
      replicas    = 2
    }
    backend = {
      port        = 8080
      health_path = "/api/health"
      replicas    = 3
    }
    database = {
      port        = 5432
      health_path = "/db-health"
      replicas    = 1
    }
  }
}

# Create configuration for each component
resource "local_file" "component_config" {
  for_each = var.website_components
  
  filename = "${each.key}-service.yaml"
  content = <<-EOF
    # ${each.key} Service Configuration
    apiVersion: v1
    kind: Service
    metadata:
      name: ${each.key}-service
    spec:
      port: ${each.value.port}
      replicas: ${each.value.replicas}
      healthCheck:
        path: ${each.value.health_path}
  EOF
}

# Output summary
output "services_created" {
  value = {
    for name, config in var.website_components :
    name => {
      filename = local_file.component_config[name].filename
      port     = config.port
      replicas = config.replicas
    }
  }
}
```

## Quick Reference

### Count Syntax:
```     
resource "resource_type" "name" {
  count = NUMBER
  # Use count.index (starts at 0)
}
```

### For_Each Syntax:
```     
resource "resource_type" "name" {
  for_each = MAP_OR_SET
  # Use each.key and each.value
}
```

### Common Patterns:
```     
# Count with variable
count = var.number_of_things

# Count with list length
count = length(var.list_of_things)

# Conditional count
count = var.create_this ? 1 : 0

# For_each with map
for_each = var.map_of_things

# For_each with set from list
for_each = toset(var.list_of_things)
```

## What's Next?

Great job! You now know how to create multiple resources efficiently:

✅ **Count** – for creating identical resources  
✅ **For_Each** – for creating configured resources  
✅ **When to use each approach**  
✅ **Working with lists, maps, and sets**  
✅ **Real-world examples and patterns**  

