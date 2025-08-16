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

  # System setup: base packages, developer user, and GUI environment
  provisioner "shell" {
    inline_shebang = "/bin/bash"
    inline = [
      "set -euo pipefail",
      "export DEBIAN_FRONTEND=noninteractive",

      # Base system packages
      "apt-get update",
      "apt-get install -y python3-pip docker.io docker-compose-v2 git xfce4 xfce4-goodies dbus-x11 wget ca-certificates curl unzip lightdm",
      "systemctl enable docker",
      "usermod -aG docker root",

      # Create developer user with password and proper groups
      "id -u developer >/dev/null 2>&1 || adduser --disabled-password --gecos '' developer",
      "echo 'developer:ch3ap' | chpasswd",
      "usermod -aG sudo,docker,video,audio,plugdev,netdev developer",

      # Configure passwordless sudo
      "echo 'developer ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/developer",
      "chmod 0440 /etc/sudoers.d/developer",

      # Set up GUI environment
      "systemctl set-default graphical.target",
      "mkdir -p /etc/lightdm/lightdm.conf.d",
      "bash -lc \"printf '%s\\n' '[Seat:*]' 'autologin-user=developer' 'autologin-user-timeout=0' > /etc/lightdm/lightdm.conf.d/50-autologin.conf\"",

      # Configure developer home and XFCE session
      "mkdir -p /home/developer/.config",
      "bash -lc 'echo startxfce4 > /home/developer/.xsession'",
      "chown -R developer:developer /home/developer",
    ]
  }

  # Development tools: editors, CLI tools, OpenTofu, and configurations
  provisioner "shell" {
    inline_shebang = "/bin/bash"
    inline = [
      "set -euo pipefail",
      "export DEBIAN_FRONTEND=noninteractive",

      # Install development tools and prerequisites
      "apt-get update",
      "apt-get install -y snapd neovim ripgrep fd-find gpg software-properties-common apt-transport-https",

      # Install Zellij from GitHub releases (hardcoded to v0.43.1)
      "curl -fL https://github.com/zellij-org/zellij/releases/download/v0.43.1/zellij-aarch64-unknown-linux-musl.tar.gz -o /tmp/zellij.tar.gz",
      "tar -xzf /tmp/zellij.tar.gz -C /usr/local/bin",
      "rm /tmp/zellij.tar.gz",
      "chmod +x /usr/local/bin/zellij",

      # Firefox: Install via Mozilla APT repository (recommended method)
      # Create directory for APT repository keyrings
      "install -d -m 0755 /etc/apt/keyrings",
      
      # Import Mozilla APT repository signing key
      "wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null",
      
      # Add Mozilla APT repository to sources list
      "echo 'deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main' | tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null",
      
      # Configure APT preferences to prioritize packages from Mozilla repository
      "echo '' | tee /etc/apt/preferences.d/mozilla",
      "echo 'Package: *' | tee -a /etc/apt/preferences.d/mozilla",
      "echo 'Pin: origin packages.mozilla.org' | tee -a /etc/apt/preferences.d/mozilla",
      "echo 'Pin-Priority: 1000' | tee -a /etc/apt/preferences.d/mozilla",
      
      # Update package information and install Firefox
      "apt-get update",
      "apt-get install -y firefox",

      # OpenTofu: Install from GitHub releases (more reliable)
      "TOFU_VERSION=$(curl -s https://api.github.com/repos/opentofu/opentofu/releases/latest | grep 'tag_name' | cut -d'\"' -f4 | sed 's/^v//')",
      "curl -L \"https://github.com/opentofu/opentofu/releases/download/v$${TOFU_VERSION}/tofu_$${TOFU_VERSION}_linux_arm64.zip\" -o /tmp/tofu.zip",
      "unzip -o /tmp/tofu.zip -d /tmp/",
      "mv /tmp/tofu /usr/local/bin/tofu",
      "chmod +x /usr/local/bin/tofu",
      "rm /tmp/tofu.zip",

      # Create fd alias for convenience
      "update-alternatives --install /usr/bin/fd fd /usr/bin/fdfind 50 || true",

      # Bootstrap LazyVim for developer user
      "runuser -l developer -c 'mkdir -p ~/.config'",
      "runuser -l developer -c 'git clone https://github.com/LazyVim/starter ~/.config/nvim'",
      "runuser -l developer -c 'rm -rf ~/.config/nvim/.git'",
      "chown -R developer:developer /home/developer/.config",
    ]
  }

  # Install NoMachine
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

  # Post-processors to export the built image ID and create a manifest
  # Active (Windows PowerShell): writes image.auto.tfvars and manifest.json
  post-processor "shell-local" {
    inline = [
      "powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/extract-snapshot-id.ps1 -ArtifactId '{{ .ArtifactId }}' -BuildName '{{ .BuildName }}' -BuilderType '{{ .BuilderType }}'"
    ]
  }

  /*
  # Optional (Linux/macOS bash): comment kept for portability; generates same image.auto.tfvars
  post-processor "shell-local" {
    inline = [
      "ID=\"{{ .ArtifactId }}\"; ID_NUM=\"${ID##*:}\"; printf 'hcloud_image_id = \"%s\"\\n' \"$ID_NUM\" > image.auto.tfvars"
    ]
  }
  */

  # Cleanup
  provisioner "shell" {
    inline_shebang = "/bin/bash"
    inline = [
      "set -euo pipefail",
      "apt-get clean -y",
      "rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*",
    ]
  }
}
