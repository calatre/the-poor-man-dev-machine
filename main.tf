terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

# The provider will read the token from the HCLOUD_TOKEN environment variable.
provider "hcloud" {}

resource "hcloud_ssh_key" "default" {
  name       = "default"
  public_key = file(var.ssh_public_key_path)
}

resource "hcloud_server" "cax31" {
  name        = "cax31-ubuntu"
  server_type = "cax31"
  # Use snapshot when provided; otherwise default image
  image    = coalesce(var.snapshot, var.image)
  location = "nbg1" # nuremberg
  ssh_keys = [hcloud_ssh_key.default.id]

  # Apply system keyboard layout at boot via cloud-init
  user_data = file("${path.module}/cloud-config.yaml")
}

resource "hcloud_firewall" "allow-ssh-app" {
  name = "allow-ssh-app"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "4000"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "4000"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_firewall_attachment" "attach-fw" {
  firewall_id = hcloud_firewall.allow-ssh-app.id
  server_ids  = [hcloud_server.cax31.id]
}

variable "image" {
  description = "Base image name to use when no snapshot is provided"
  type        = string
  default     = "ubuntu-24.04"
}

variable "snapshot" {
  description = "Hetzner snapshot ID or name to boot from (takes precedence over image)"
  type        = string
  default     = null
  nullable    = true
}

variable "ssh_public_key_path" {}

output "server_ipv4" {
  description = "Public IPv4 address of the server"
  value       = hcloud_server.cax31.ipv4_address
}
