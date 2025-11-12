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