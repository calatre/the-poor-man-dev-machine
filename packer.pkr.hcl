# Packer HCL2 template for Hetzner Cloud ARM image with XFCE + NoMachine

packer {
  required_plugins {
    hcloud = {
      version = ">= 1.0.0"
      source  = "github.com/hetznercloud/hcloud"
    }
  }
}

variable "hcloud_token" {
  type      = string
  sensitive = true
  default   = null
}


source "hcloud" "ubuntu" {
  # Token is provided via variable hcloud_token (set with PACKER_VAR_hcloud_token)
  token        = var.hcloud_token
  server_type  = "cax31"
  image        = "ubuntu-24.04"
  location     = "nbg1"
  ssh_username = "root"
}

build {
  sources = [
    "source.hcloud.ubuntu",
  ]

  provisioner "shell" {
    inline_shebang = "/bin/bash"
    inline = [
      "set -euo pipefail",
      "export DEBIAN_FRONTEND=noninteractive",
      "apt-get update",
      "apt-get install -y python3-pip docker.io docker-compose-v2 git xfce4 xfce4-goodies dbus-x11 wget ca-certificates curl unzip",
      "systemctl enable docker",
      "usermod -aG docker root",
    ]
  }

provisioner "shell" {
    inline_shebang = "/bin/bash"
    inline = [
      "set -euo pipefail",
      "echo 'Downloading NoMachine from hardcoded URL...'",
      "NX_URL='https://web9001.nomachine.com/download/9.1/Arm/nomachine_9.1.24_6_arm64.deb'",
      "curl -L -A 'Mozilla/5.0' -o /tmp/nomachine.deb \"$NX_URL\"",
      "echo 'Installing NoMachine...'",
      "apt-get install -y --allow-downgrades /tmp/nomachine.deb || dpkg -i /tmp/nomachine.deb",
      "echo 'Enabling NoMachine service...'",
      "systemctl enable --now nxserver || systemctl enable --now nomachine || true",
    ]
  }

  provisioner "shell" {
    inline_shebang = "/bin/bash"
    inline = [
      "set -euo pipefail",
      "apt-get clean -y",
      "rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*",
    ]
  }
}
