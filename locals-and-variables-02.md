# Terraform Variables and Locals: Making Your Code Flexible

Variables and locals are what make Terraform code reusable and flexible. Think of variables as empty boxes that you can put different things in. The same box, different contents each time.

## The Problem: Hard-Coded Values

Remember our first example? It looked like this:

```
resource "local_file" "hello" {
  content  = "Hello, Terraform World!"
  filename = "hello.txt"
}
```

This works, but what if you want to say hello to someone else? You'd have to edit the code. Not very flexible, right?

## Your First Variable: String Type

Let's make it flexible with a string variable. A string is just text.

```
variable "name" {
  type    = string
  default = "World"
}

resource "local_file" "hello" {
  content  = "Hello, ${var.name}!"
  filename = "hello.txt"
}
```

**New things explained:**
- `variable "name"` – creates a variable called "name"
- `type = string` – tells Terraform this variable holds text
- `default = "World"` – the value to use if no one provides one
- `${var.name}` – this is called string interpolation. The `${}` tells Terraform to replace this with the variable's value

Try this! Create this code in a new folder and run:

```bash
terraform init
terraform apply
```

You'll get a file saying "Hello, World!"

## Changing Variable Values

Want to greet someone else? You can change the variable value:

```bash
terraform apply -var="name=Alice"
```

Now your file will say "Hello, Alice!" Cool, right?

## Variable Type #2: Number

Numbers are for… well, numbers! Let's see how they work:

```
variable "count" {
  type    = number
  default = 5
}

resource "local_file" "counter" {
  content  = "You have ${var.count} apples"
  filename = "count.txt"
}
```

Try this:

```bash
terraform apply
# Creates: "You have 5 apples"

terraform apply -var="count=10"
# Creates: "You have 10 apples"
```

Notice we don't need quotes around numbers when setting them.

## Variable Type #3: Bool (True/False)

Bool variables can only be true or false. They're perfect for on/off settings:

```
variable "is_weekend" {
  type    = bool
  default = false
}

resource "local_file" "mood" {
  content  = "Happy weekend: ${var.is_weekend}"
  filename = "weekend.txt"
}
```

Try this:

```bash
terraform apply
# Creates: "Happy weekend: false"

terraform apply -var="is_weekend=true"
# Creates: "Happy weekend: true"
```

## Combining Multiple Variables

Let's use all three types together:

```
variable "user_name" {
  type    = string
  default = "Bob"
}

variable "age" {
  type    = number
  default = 25
}

variable "likes_pizza" {
  type    = bool
  default = true
}

resource "local_file" "profile" {
  content  = "Name: ${var.user_name}, Age: ${var.age}, Likes Pizza: ${var.likes_pizza}"
  filename = "profile.txt"
}
```

Run this and see what happens! Try changing the values:

```bash
terraform apply -var="user_name=Alice" -var="age=30" -var="likes_pizza=false"
```

## Variable Descriptions – Always a Good Idea

You should always add descriptions to explain what your variables do:

```
variable "city" {
  type        = string
  description = "The city where the user lives"
  default     = "New York"
}

resource "local_file" "location" {
  content  = "I live in ${var.city}"
  filename = "location.txt"
}
```

The description helps you (and others) remember what the variable is for.

## Multi-Line Content with EOF

So far, we've used simple, one-line content. But what if you want multiple lines? That's where EOF comes in.

**EOF explained:** EOF stands for "End Of File". The `<<-EOF` and `EOF` create a multi-line string.

```
variable "student_name" {
  type        = string
  description = "Name of the student"
  default     = "John"
}

variable "grade" {
  type        = string
  description = "Student's grade"
  default     = "A"
}

resource "local_file" "report_card" {
  filename = "report.txt"
  content = <<-EOF
    Student Report Card
    ===================
    
    Student Name: ${var.student_name}
    Grade: ${var.grade}
    
    Great job!
  EOF
}
```

**How EOF works:**
- `<<-EOF` starts the multi-line text
- Everything between the start and end is included
- `EOF` ends the multi-line text
- You can use variables inside with `${var.name}`

## Setting Variables with Files

Instead of typing variables on the command line every time, you can create a file called `terraform.tfvars`:

```
student_name = "Alice"
grade = "A+"
```

Now just run `terraform apply` and it will use these values automatically!

## What Are Locals and Why Do We Need Them?

Sometimes you want to combine variables or do simple calculations. That's where locals come in.

- **Variables** are for input (values from outside)
- **Locals** are for calculations (values computed inside)

Here's a simple example:

```
variable "first_name" {
  type    = string
  default = "John"
}

variable "last_name" {
  type    = string
  default = "Doe"
}

locals {
  full_name = "${var.first_name} ${var.last_name}"
}

resource "local_file" "name_card" {
  content  = "Hello, my name is ${local.full_name}"
  filename = "namecard.txt"
}
```

**What happened here:**
- We have two variables: `first_name` and `last_name`
- We use `locals` to combine them into `full_name`
- We reference locals with `local.` (not `var.`)

## More Local Examples

Locals are great for avoiding repetition:

```
variable "app_name" {
  type    = string
  default = "myapp"
}

variable "environment" {
  type    = string
  default = "dev"
}

locals {
  server_name = "${var.app_name}-${var.environment}-server"
}

resource "local_file" "server_info" {
  filename = "${local.server_name}.txt"
  content  = "Server name is: ${local.server_name}"
}
```

This creates a file called `myapp-dev-server.txt` with the content "Server name is: myapp-dev-server".

## Simple Logic with Locals

Locals can also do simple if-then logic:

```
variable "environment" {
  type    = string
  default = "dev"
}

locals {
  is_production = var.environment == "prod"
  backup_enabled = var.environment == "prod" ? true : false
}

resource "local_file" "config" {
  filename = "config.txt"
  content = <<-EOF
    Environment: ${var.environment}
    Is Production: ${local.is_production}
    Backup Enabled: ${local.backup_enabled}
  EOF
}
```

**What's `? :`?** This is a ternary operator:
- `condition ? value_if_true : value_if_false`
- If `var.environment == "prod"` is true, use `true`
- Otherwise, use `false`

## Outputs: Showing Results

Sometimes you want to see variable values after Terraform runs. Use outputs for this:

```
variable "user_name" {
  type    = string
  default = "Alice"
}

locals {
  greeting = "Hello, ${var.user_name}!"
}

resource "local_file" "greeting_file" {
  content  = local.greeting
  filename = "greeting.txt"
}

output "user_greeting" {
  value = local.greeting
}

output "file_created" {
  value = "greeting.txt"
}
```

After running `terraform apply`, you'll see:

```
Outputs:

file_created = "greeting.txt"
user_greeting = "Hello, Alice!"
```

## Complete Simple Example

Let's put it all together in a simple, practical example:

```
# Variables (input from user)
variable "team_name" {
  type        = string
  description = "Name of the team"
  default     = "DevOps"
}

variable "project_id" {
  type        = number
  description = "Project ID number"
  default     = 123
}

variable "is_active" {
  type        = bool
  description = "Is the project active?"
  default     = true
}

# Locals (calculated values)
locals {
  project_name = "Project-${var.project_id}"
  status = var.is_active ? "Active" : "Inactive"
  team_info = "${var.team_name} Team"
}

# Resource using variables and locals
resource "local_file" "project_summary" {
  filename = "${local.project_name}-summary.txt"
  content = <<-EOF
    Project Summary
    ===============
    
    Project: ${local.project_name}
    Team: ${local.team_info}
    Status: ${local.status}
    
    Created by Terraform
  EOF
}

# Output the results
output "project_info" {
  value = {
    name   = local.project_name
    team   = local.team_info
    status = local.status
  }
}
```

Create a `terraform.tfvars` file to test different values:

```
team_name = "Frontend"
project_id = 456
is_active = false
```

Run `terraform apply` and see how everything changes!

## Quick Reference

**Variable Declaration:**
```
variable "name" {
  type        = string
  description = "What this variable is for"
  default     = "default_value"
}
```

**Variable Usage:**
```
"${var.variable_name}"
```

**Local Declaration:**
```
locals {
  computed_value = "${var.first} ${var.second}"
}
```

**Local Usage:**
```
"${local.computed_value}"
```

**Output:**
```
output "result" {
  value = local.computed_value
}
```

## Practice Exercise

Try this yourself:
1. Make variables for your favorite food, favorite number, and whether you like coffee
2. Use locals to create a message combining all three
3. Create a file with your preferences
4. Use outputs to display your message

## What's Next?

Great work! You now know how to make your Terraform code flexible with variables and locals. You understand:

✅ String, number, and bool variables  
✅ How to use `${var.name}` to insert variable values  
✅ Multi-line content with `<<-EOF`  
✅ Setting variables with `.tfvars` files  
✅ Using locals for calculations  
✅ Displaying results with outputs  

In our next post, we'll learn about **Terraform Providers** – the plugins that let Terraform work with different services like AWS, Azure, and Google Cloud. You'll learn how to set them up and use them safely.