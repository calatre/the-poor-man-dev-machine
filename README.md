# Cheap and High-Performance Cloud Development Environment, with Packer and OpenTofu on Hetzner Cloud

- Do you, like me, have a crappy and/or aging laptop that easily gets irresponsive if you put a little charge on it?
- Did you, like me, think about buying something like a 32GB+ RAM Macbook but your girlfriend (or boyfriend) says "Nope. Aren't you some kind of cloud engineer? Make up some cloud solution, I don't know..."
- Do you also think that Github Codespaces sounds great, but you would like extra control, lower costs or even to offload some of your everyday GUI applications (Web browser for example)?

This project provides the configuration to create a powerful, persistent, and cost-effective cloud development workstation using Packer and OpenTofu (Terraform if you prefer), hosted on Hetzner Cloud (cheap and European!). Any tiny PC can then become a simple light client/terminal to it.

The end result is a full Ubuntu XFCE desktop environment running on a **Hetzner CAX31** cloud server, accessible from your local machine via the high-performance **NoMachine (NX Protocol)**. You can easily create and destroy the machine to manage costs, while the Packer image ensures a consistent and reproducible setup.

## Core Technologies

*   **Packer**: Builds a custom machine image for Hetzner Cloud, pre-loaded with a desktop environment and some basic development tools.
*   **OpenTofu (or Terraform)**: Provisions the cloud infrastructure on Hetzner, launching a server from the custom Packer image.
*   **Hetzner Cloud**: The cloud provider used for hosting the virtual machine.
*   **NoMachine**: Provides high-performance, low-latency remote desktop access.
*   ***Later - Devpod***: use .devcontainer.json files to quickly spin up different environments for each project of yours, kind of your own opensource Github Codespaces on your machine.

## Machine Characteristics

*   **Cloud Provider**: [Hetzner](https://www.hetzner.com/cloud)
*   **Instance Type**: CAX31 (8 vCPUs (ARM), 16 GB RAM, €0.02/h - that's like 0.80€ for a 40h work week!))
*   **Operating System**: Ubuntu 24.04
*   **Desktop Environment**: XFCE4
*   **Key Software**:
    *   NoMachine Server (for GUI remote access)
    *   Docker, Python, Git...

## Prerequisites

Before you begin, ensure you have the following installed on your local machine:

1.  **Packer**: [Installation Guide](https://developer.hashicorp.com/packer/tutorials/docker-get-started/install-cli)
2.  **OpenTofu**: [Installation Guide](https://opentofu.org/docs/intro/install/)
3.  **NoMachine Enterprise Client**: Download and install the free client for your local OS from [nomachine.com](https://www.nomachine.com/download).
4.  **Hetzner Cloud Account**: You will need a Hetzner Cloud account and an API token.

## Usage

### Step 1: Configure Credentials

Both Packer and OpenTofu need your Hetzner Cloud API token.

1.  **Get an API Token**: Log in to your Hetzner Cloud Console. Create a new project, and in that project, go to `Security` -> `API tokens` and generate a new **Read & Write** token.

2.  **Set Environment Variable**: Expose the token as an environment variable. This is the most secure method and avoids hardcoding it in your configuration files.

    ```bash
    export HCLOUD_TOKEN="your_hetzner_api_token"
    ```

   Alternatively, use the example scripts to load your Hetzner token and SSH public key path into this shell session:

   - PowerShell (Windows):

     ```powershell
     .\scripts\load-dev-secrets-example.ps1 -TokenPath "<your-hetzner-token-path>" -SshPublicKeyPath "<your-ssh-key-path>"
     ```

   - Unix shells (bash/zsh):

     ```bash
     source ./scripts/load-dev-secrets-example.sh "<your-hetzner-token-path>" "<your-ssh-key-path>"
     ```

   These scripts set the following environment variables for you:

   - `TF_VAR_hcloud_token`
   - `HCLOUD_TOKEN`
   - `PACKER_VAR_hcloud_token`
   - `TF_VAR_ssh_public_key_path`

   Notes:
   - Replace the placeholders with your real local paths (e.g., `C:\Users\you\.ssh\id_ed25519.pem` on Windows or `$HOME/.ssh/id_ed25519.pem` on Unix).
   - You can also just hardcode your localpaths or variables in the script of course. (I would say easier if you launch multiple times)

### Step 2: Build the Packer Image

Navigate to the `packer` directory and run the build command.

```bash
cd packer
packer init .
packer build .
```

Packer will connect to Hetzner, create a temporary server, run the setup scripts (installing XFCE, NoMachine, etc.), and then create a snapshot (image) of that server. This process can take 5-10 minutes. Once complete, you will see the ID of the new image in the output. Note it down for now.

*Note* - Improvements to come here: the goal is for this snapshot ID to output as a variable for the next step.

### Step 3: Deploy the Infrastructure with OpenTofu

Navigate to the `opentofu` directory.

1.  **Initialize OpenTofu**:

    ```bash
    cd ../opentofu
    tofu init
    ```

2.  **Review and Apply the Plan**:

    ```bash
    tofu plan -var snapshot=<your-snapshot-id>
    tofu apply -var snapshot=<your-snapshot-id> #for now, with future improvements this won't be needed.
    ```

   OpenTofu will show you the resources it plans to create. Type `yes` to confirm. It will then provision a `cax31` server using the Packer image you just built and set up the necessary networking.

### Step 4: Connect with NoMachine

1.  **Get the Server IP**: After `tofu apply` completes, the server's public IP address will be in the output.
2.  **Connect**: Open your local NoMachine client.
    *   Create a new connection, using the server's IP address as the **Host**.
    *   *Note* - at this point I still had to ssh first as root to create a user and make it usable for the GUI. More improvements to come here.

You will connect to a full-featured, responsive Linux desktop.

## Cost Management

Cloud resources incur costs while they are running.

To stop all costs, you must **destroy** the infrastructure. This will delete the server, but your custom Packer image remains in your Hetzner account, ready for the next time you need it.

```bash
# From the opentofu directory
tofu destroy
```

When you need the environment again, simply run `tofu apply -var snapshot=<your-snapshot-id>` to quickly provision a new server from your image.

