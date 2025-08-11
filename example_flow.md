# Example Test Flow

This guide walks you through a clean, secure test of the image build (Packer) and provisioning (OpenTofu/Terraform), then connecting to the GUI over NoMachine (NX) on port 4000.

Prerequisites
- PowerShell 7+
- Packer installed and in PATH
- OpenTofu (or Terraform) installed and in PATH
- Hetzner token saved at a location of your choice (ex: C:\Users\<your-user>\token.txt )
- SSH public key (ex: C:\Users\<your-user>\.ssh\<your-key>.pub )
- NoMachine client installed on your local machine

1) Load environment for this session
- This sets HCLOUD_TOKEN (for provider/builder), PACKER_VAR_hcloud_token, and TF_VAR_ssh_public_key_path without printing the secret.

& .\scripts\load-dev-secrets.ps1  # Run in current PowerShell session so env vars persist

2) Initialize, validate and build image with Packer
- Initialize plugins and dependencies:

packer init .

- Validate the template:

packer validate .

- Build the image (reads hcloud_token from PACKER_VAR_hcloud_token):

packer build .

3) Provision infrastructure with OpenTofu
- Initialize and plan:

tofu init
tofu plan -out=tfplan

- Apply and wait for completion:

tofu apply tfplan

- The apply prints server_ipv4. Copy that IP.

4) Allow-list notes (optional but recommended)
- For better security, consider restricting firewall rules to your home IP(s) in main.tf. Current setup is open (0.0.0.0/0 and ::/0) for testing.

5) Connect with NoMachine
- Open the NoMachine client on your PC.
- Create a new connection:
  - Protocol: NX
  - Host: <server_ipv4_from_apply>
  - Port: 4000
  - Authentication: System account (e.g., root or a user you create later)
- You should get an XFCE desktop session.

Quick checks / troubleshooting
- Confirm NoMachine service:
  - SSH into the server, then run:
    systemctl status nxserver || systemctl status nomachine
    sudo systemctl enable --now nxserver || sudo systemctl enable --now nomachine

- Confirm desktop and NoMachine packages:
  dpkg -l | grep -E "(xfce4|dbus-x11|nomachine)"

- Confirm listener on port 4000:
  sudo ss -lntup | grep 4000

- If the NoMachine download fails during Packer build:
  - The upstream filename may have changed. Update nx_version or the base URL in packer.json accordingly, or adjust the architecture mapping if needed (arm64 vs aarch64).

Cleanup
- To remove infrastructure and stop incurring charges:

tofu destroy

- Images created by Packer remain until removed in Hetzner Cloud Console.

Security reminders
- Never print your token to the console.
- Keep token files and private keys outside the repository (or ensure they are ignored by Git).
- HCLOUD_TOKEN is used by the provider; it should not appear in state.

