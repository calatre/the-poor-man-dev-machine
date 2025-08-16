terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# The provider will read the token from the HCLOUD_TOKEN environment variable.
provider "hcloud" {}

# Fallback to the most recent snapshot if no image is provided via env/auto.tfvars
data "hcloud_image" "latest_snapshot" {
  #with_selector        = "<tags to filter -  good practice if you use multiple snapshots>""
  most_recent = true
}

resource "hcloud_ssh_key" "default" {
  name       = "default"
  public_key = file(var.ssh_public_key_path)
}

resource "hcloud_server" "cax31" {
  name        = "cax31-ubuntu"
  server_type = "cax31"
  # Image selection precedence:
  # 1) var.hcloud_snapshot_id (snapshot ID set via TF_VAR_hcloud_snapshot_id or snapshot.auto.tfvars)
  # 2) latest snapshot in the Hetzner project
  image    = coalesce(var.hcloud_snapshot_id, data.hcloud_image.latest_snapshot.id)
  location = "nbg1" # nuremberg
  ssh_keys = [hcloud_ssh_key.default.id]

  # Apply system keyboard layout at boot via cloud-init
  user_data = file("${path.module}/cloud-config.yaml")
}

# Write a minimal SSH config snippet for this server to your home SSH folder.
# This creates ~/.ssh/dev-srv-ubu.conf which you can include from ~/.ssh/config.
resource "local_file" "ssh_config_snippet" {
  filename = pathexpand("~/.ssh/dev-srv-ubu.conf")
content = join("\n", compact([
    "Host dev-srv-ubu",
    "  HostName ${hcloud_server.cax31.ipv4_address}",
    "  User ${var.ssh_user}",
    var.ssh_private_key_path != null ? "  IdentityFile ${var.ssh_private_key_path}" : null,
    "  IdentitiesOnly yes",
    "  PreferredAuthentications publickey",
    "  PubkeyAuthentication yes",
    "  StrictHostKeyChecking no",
    "  UserKnownHostsFile=/dev/null"
  ]))

  depends_on = [hcloud_server.cax31]
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

variable "hcloud_snapshot_id" {
  description = "Hetzner snapshot ID. Set via TF_VAR_hcloud_snapshot_id or snapshot.auto.tfvars. If unset, the most recent snapshot is used."
  type        = string
  default     = null
  nullable    = true
}

variable "ssh_public_key_path" {}

variable "ssh_user" {
  description = "SSH user for connecting to the server (Hetzner Ubuntu images default to root)"
  type        = string
  default     = "root"
}

variable "ssh_private_key_path" {
  description = "Path to your private SSH key for this host. If null, IdentityFile will be omitted."
  type        = string
  default     = null
  nullable    = true
}

output "server_ipv4" {
  description = "Public IPv4 address of the server"
  value       = hcloud_server.cax31.ipv4_address
}
