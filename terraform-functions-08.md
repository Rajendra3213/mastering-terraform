# Terraform Functions: Your Swiss Army Knife for Data

Terraform functions – built-in tools that help you do amazing things with your data.

Think of functions like a Swiss Army knife for your code.

Need to make text uppercase? There's a function for that.
Want to combine two lists? There's a function for that too.
Need to do some math? Yep, functions to the rescue!

## What Are Functions?

Functions are like little helpers that take some input, do something useful with it, and give you back a result.

Here's the basic pattern:

```   
result = function_name(input)
```

Let's see a super simple example:

```   
variable "my_name" {
  type    = string
  default = "john smith"
}

locals {
  clean_name = upper(var.my_name)
}

output "formatted_name" {
  value = local.clean_name
}
```

**What happened?**
- `upper()` is a function that makes text uppercase
- **Input:** "john smith"
- **Output:** "JOHN SMITH"

Pretty simple, right?

## String Functions: Working with Text

Let's start with functions that help you work with text.

### Making Text Look Nice

```   
variable "user_input" {
  type    = string
  default = "  Hello World  "
}

locals {
  # Remove extra spaces
  clean_text = trim(var.user_input, " ")
  
  # Make it uppercase
  upper_text = upper(local.clean_text)
  
  # Make it lowercase
  lower_text = lower(local.clean_text)
  
  # Make first letter uppercase
  title_text = title(local.clean_text)
}

output "text_examples" {
  value = {
    original = var.user_input
    clean    = local.clean_text
    upper    = local.upper_text
    lower    = local.lower_text
    title    = local.title_text
  }
}
```

This shows:
- `trim()` removes spaces from the beginning and end
- `upper()` makes everything UPPERCASE
- `lower()` makes everything lowercase
- `title()` Makes The First Letter Of Each Word Uppercase

### Finding and Replacing Text

```   
variable "server_name" {
  type    = string
  default = "my-awesome-server"
}

locals {
  # Replace dashes with underscores
  underscore_name = replace(var.server_name, "-", "_")
  
  # Replace multiple things
  clean_name = replace(replace(var.server_name, "-", "_"), "awesome", "super")
}

resource "local_file" "server_config" {
  filename = "${local.underscore_name}.conf"
  content  = "Server name: ${local.clean_name}"
}

output "name_changes" {
  value = {
    original   = var.server_name
    underscore = local.underscore_name
    clean      = local.clean_name
  }
}
```

**What `replace()` does:**
- `replace(text, old, new)` finds "old" text and replaces it with "new" text
- You can chain multiple `replace()` functions together

### Combining Text

```   
variable "first_name" {
  type    = string
  default = "John"
}

variable "last_name" {
  type    = string
  default = "Doe"
}

variable "company" {
  type    = string
  default = "TechCorp"
}

locals {
  # Simple joining
  full_name = "${var.first_name} ${var.last_name}"
  
  # Using format function (like printf)
  email = format("%s.%s@%s.com", lower(var.first_name), lower(var.last_name), lower(var.company))
  
  # Join with specific separator
  name_parts = join("-", [var.first_name, var.last_name, var.company])
}

output "name_formatting" {
  value = {
    full_name  = local.full_name
    email      = local.email
    name_parts = local.name_parts
  }
}
```

**New functions:**
- `format()` is like a template – `%s` gets replaced with the values
- `join()` combines a list with a separator between items

## List Functions: Working with Lists

Lists are super useful, and Terraform has lots of functions to work with them.

### Basic List Operations

```   
variable "fruits" {
  type    = list(string)
  default = ["apple", "banana", "cherry"]
}

variable "vegetables" {
  type    = list(string)
  default = ["carrot", "broccoli"]
}

locals {
  # How many items?
  fruit_count = length(var.fruits)
  
  # Combine lists
  all_food = concat(var.fruits, var.vegetables)
  
  # Check if something exists
  has_apple = contains(var.fruits, "apple")
  has_pizza = contains(var.fruits, "pizza")
  
  # Get specific items
  first_fruit = var.fruits[0]
  last_fruit  = var.fruits[length(var.fruits) - 1]
}

output "list_operations" {
  value = {
    fruit_count = local.fruit_count
    all_food    = local.all_food
    has_apple   = local.has_apple
    has_pizza   = local.has_pizza
    first_fruit = local.first_fruit
    last_fruit  = local.last_fruit
  }
}
```

**What these functions do:**
- `length()` counts items in a list
- `concat()` combines multiple lists into one
- `contains()` checks if an item exists in a list (true/false)

### Sorting and Organizing Lists

```   
variable "server_names" {
  type    = list(string)
  default = ["web-03", "api-01", "db-02", "web-01", "api-02"]
}

locals {
  # Sort alphabetically
  sorted_servers = sort(var.server_names)
  
  # Reverse the order
  reversed_servers = reverse(local.sorted_servers)
  
  # Remove duplicates (if any)
  unique_servers = distinct(var.server_names)
  
  # Get just part of the list
  first_three = slice(local.sorted_servers, 0, 3)
}

output "list_sorting" {
  value = {
    original    = var.server_names
    sorted      = local.sorted_servers
    reversed    = local.reversed_servers
    unique      = local.unique_servers
    first_three = local.first_three
  }
}
```

**New functions:**
- `sort()` puts items in alphabetical order
- `reverse()` flips the order
- `distinct()` removes duplicate items
- `slice(list, start, end)` gets items from position start to end

## Map Functions: Working with Key-Value Pairs

Maps are like dictionaries – they have keys and values. Here's how to work with them:

```   
variable "server_config" {
  type = map(string)
  default = {
    web      = "t2.micro"
    database = "t2.small"
    cache    = "t2.nano"
  }
}

variable "additional_config" {
  type = map(string)
  default = {
    backup  = "t2.micro"
    monitor = "t2.nano"
  }
}

locals {
  # Get all the keys
  server_types = keys(var.server_config)
  
  # Get all the values
  instance_sizes = values(var.server_config)
  
  # Combine maps
  all_servers = merge(var.server_config, var.additional_config)
  
  # Check if a key exists
  has_web_server = contains(keys(var.server_config), "web")
}

output "map_operations" {
  value = {
    server_types   = local.server_types
    instance_sizes = local.instance_sizes
    all_servers    = local.all_servers
    has_web_server = local.has_web_server
  }
}
```

**Map functions:**
- `keys()` gets all the keys (left side)
- `values()` gets all the values (right side)
- `merge()` combines multiple maps
- Use `contains(keys(map), "key_name")` to check if a key exists

## Math Functions: Doing Calculations

Sometimes you need to do math in your Terraform code:

```   
variable "server_count" {
  type    = number
  default = 7
}

variable "cpu_per_server" {
  type    = number
  default = 2.5
}

variable "monthly_cost" {
  type    = number
  default = 45.99
}

locals {
  # Round numbers
  rounded_cpu = ceil(var.cpu_per_server)  # Round up to 3
  floored_cpu = floor(var.cpu_per_server) # Round down to 2
  
  # Find min and max
  min_servers = min(var.server_count, 5)
  max_servers = max(var.server_count, 10)
  
  # Calculate total costs
  total_cpu = var.server_count * var.cpu_per_server
  yearly_cost = var.monthly_cost * 12
  
  # Get absolute value (always positive)
  difference = abs(var.server_count - 10)
}

output "math_examples" {
  value = {
    original_cpu = var.cpu_per_server
    rounded_up   = local.rounded_cpu
    rounded_down = local.floored_cpu
    min_servers  = local.min_servers
    max_servers  = local.max_servers
    total_cpu    = local.total_cpu
    yearly_cost  = local.yearly_cost
    difference   = local.difference
  }
}
```

**Math functions:**
- `ceil()` rounds up to the next whole number
- `floor()` rounds down to the previous whole number
- `min()` finds the smallest number
- `max()` finds the largest number
- `abs()` makes negative numbers positive

## Type Conversion Functions: Changing Data Types

Sometimes you need to convert between different types of data:

```   
variable "port_number" {
  type    = string
  default = "8080"
}

variable "server_count" {
  type    = number
  default = 3
}

variable "feature_flags" {
  type    = list(string)
  default = ["ssl", "backup", "monitoring"]
}

locals {
  # Convert string to number
  port_as_number = tonumber(var.port_number)
  
  # Convert number to string
  count_as_string = tostring(var.server_count)
  
  # Convert list to set
  features_set = toset(var.feature_flags)
  
  # Convert list to map (with indices as keys)
  features_map = {
    for i, feature in var.feature_flags : i => feature
  }
}

output "type_conversions" {
  value = {
    port_number     = var.port_number
    port_as_number  = local.port_as_number
    count_as_string = local.count_as_string
    features_set    = local.features_set
    features_map    = local.features_map
  }
}
```

**Type conversion functions:**
- `tonumber()` converts string to number
- `tostring()` converts number to string
- `toset()` converts list to set
- `tolist()` converts set to list
- `tomap()` converts object to map

## Date and Time Functions

Working with dates and times:

```   
locals {
  # Current timestamp
  current_time = timestamp()
  
  # Format timestamp
  readable_time = formatdate("DD MMM YYYY hh:mm:ss ZZZ", timestamp())
  
  # Just the date
  today = formatdate("YYYY-MM-DD", timestamp())
  
  # Custom format
  custom_format = formatdate("DD/MM/YY", timestamp())
}

output "time_examples" {
  value = {
    current_time   = local.current_time
    readable_time  = local.readable_time
    today         = local.today
    custom_format = local.custom_format
  }
}
```

**Time functions:**
- `timestamp()` gets the current date and time
- `formatdate(format, timestamp)` formats dates in different ways

## Combining Functions: Real-World Examples

Let's see how to combine functions for powerful results:

### Example 1: Processing User Data

```   
variable "user_emails" {
  type    = list(string)
  default = ["  John.Doe@COMPANY.COM  ", "jane.smith@company.com", "bob.wilson@COMPANY.COM"]
}

locals {
  # Clean and standardize emails
  clean_emails = [
    for email in var.user_emails : 
    lower(trim(email, " "))
  ]
  
  # Extract usernames (part before @)
  usernames = [
    for email in local.clean_emails :
    split("@", email)[0]
  ]
  
  # Create user map
  user_map = {
    for i, email in local.clean_emails :
    local.usernames[i] => email
  }
  
  # Count unique domains
  domains = distinct([
    for email in local.clean_emails :
    split("@", email)[1]
  ])
}

output "user_processing" {
  value = {
    original_emails = var.user_emails
    clean_emails    = local.clean_emails
    usernames       = local.usernames
    user_map        = local.user_map
    unique_domains  = local.domains
    domain_count    = length(local.domains)
  }
}
```

### Example 2: Server Configuration

```   
variable "environments" {
  type = map(object({
    server_count = number
    instance_type = string
  }))
  default = {
    dev = {
      server_count  = 2
      instance_type = "t2.micro"
    }
    staging = {
      server_count  = 3
      instance_type = "t2.small"
    }
    prod = {
      server_count  = 5
      instance_type = "t2.medium"
    }
  }
}

locals {
  # Calculate total servers
  total_servers = sum([
    for env in values(var.environments) : env.server_count
  ])
  
  # Find environment with most servers
  max_servers = max([
    for env in values(var.environments) : env.server_count
  ]...)
  
  # Create server names
  all_server_names = flatten([
    for env_name, config in var.environments : [
      for i in range(config.server_count) :
      "${env_name}-server-${format("%02d", i + 1)}"
    ]
  ])
  
  # Group by instance type
  servers_by_type = {
    for instance_type in distinct(values(var.environments)[*].instance_type) :
    instance_type => [
      for env_name, config in var.environments :
      env_name if config.instance_type == instance_type
    ]
  }
}

output "server_analysis" {
  value = {
    total_servers     = local.total_servers
    max_servers       = local.max_servers
    all_server_names  = local.all_server_names
    servers_by_type   = local.servers_by_type
  }
}
```

## Quick Reference

### String Functions:
```   
upper(string)           # UPPERCASE
lower(string)           # lowercase
title(string)           # Title Case
trim(string, chars)     # Remove characters from ends
replace(string, old, new) # Replace text
format(template, ...)   # Format string with placeholders
join(separator, list)   # Join list with separator
split(separator, string) # Split string into list
```

### List Functions:
```   
length(list)           # Count items
concat(list1, list2)   # Combine lists
contains(list, value)  # Check if value exists
sort(list)            # Sort alphabetically
reverse(list)         # Reverse order
distinct(list)        # Remove duplicates
slice(list, start, end) # Get subset
```

### Map Functions:
```   
keys(map)             # Get all keys
values(map)           # Get all values
merge(map1, map2)     # Combine maps
lookup(map, key, default) # Get value or default
```

### Math Functions:
```   
min(num1, num2, ...)  # Smallest number
max(num1, num2, ...)  # Largest number
ceil(number)          # Round up
floor(number)         # Round down
abs(number)           # Absolute value
sum(list)             # Add all numbers in list
```

### Type Conversion:
```   
tostring(value)       # Convert to string
tonumber(string)      # Convert to number
tolist(set)           # Convert to list
toset(list)           # Convert to set
tomap(object)         # Convert to map
```

### Date/Time:
```   
timestamp()           # Current time
formatdate(format, time) # Format timestamp
```

## Practice Exercises

Try these yourself:

1. **Text Processing**: Take a list of messy email addresses and clean them up
2. **Data Analysis**: Calculate statistics from a list of numbers
3. **Configuration Generation**: Create server names based on environment and count
4. **Data Transformation**: Convert between different data structures

## What's Next?

Excellent work! You now have a powerful toolkit of Terraform functions:

✅ **String Functions** – text manipulation and formatting  
✅ **List Functions** – working with arrays of data  
✅ **Map Functions** – handling key-value pairs  
✅ **Math Functions** – calculations and number operations  
✅ **Type Conversion** – changing between data types  
✅ **Date/Time Functions** – working with timestamps  
✅ **Function Combinations** – creating complex data transformations  

