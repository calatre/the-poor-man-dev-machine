# Advanced DevPod Setup: High-Performance GUI Desktop with NoMachine

This guide provides step-by-step instructions to create a powerful, persistent, and cost-effective cloud development workstation using DevPod.

The end result will be a full Ubuntu XFCE desktop environment running on a **Hetzner CX42** cloud server, accessible from your local machine via the high-performance **NoMachine (NX Protocol)**. You will be able to stop the machine at any time to save costs and restart it later with all your data and tools intact.

### **Prerequisites**

1.  **DevPod Installed:** You need the DevPod CLI or the DevPod GUI installed on your local machine. [See installation instructions](https://devpod.sh/docs/getting-started/install).
2.  **NoMachine Enterprise Client:** You must install the free NoMachine client on your **local PC**. Download it from [https://www.nomachine.com/download](https://www.nomachine.com/download).
3.  **Hetzner Cloud Account:** You need an account with Hetzner Cloud.

---

### **Step 1: Configure the DevPod Provider**

First, DevPod needs API access to create machines in your Hetzner Cloud account.

1.  **Get an API Token:** Log in to your Hetzner Cloud Console. Create a new project, and in that project, go to `Security` -> `API tokens` and generate a new **Read & Write** token. Copy this token immediately as it will only be shown once.

2.  **Add Provider to DevPod:** Open your terminal and add the Hetzner provider. DevPod will prompt you to enter the token.

    ```bash
    devpod provider add hetzner
    ```

    Follow the prompts, give it a name (e.g., `my-hetzner`), and paste your API token when asked.

---

### **Step 2: Create the `devcontainer.json` File**

This file is the blueprint for your entire environment. It contains all the logic to install the desktop, NoMachine, and your development tools automatically.

Create a new folder on your local machine. Inside that folder, create a file named `devcontainer.json` and paste the following content into it.

```json
{
	"name": "Cloud-Desktop-NoMachine",
	// Use a standard Ubuntu 22.04 base image.
	"image": "[mcr.microsoft.com/devcontainers/base:ubuntu-22.04](https://mcr.microsoft.com/devcontainers/base:ubuntu-22.04)",

	// NoMachine requires port 4000 (TCP/UDP) to be forwarded.
	"forwardPorts": [4000],

	// This long command runs after the container is created. It does everything:
	// 1. Installs a lightweight XFCE desktop environment.
	// 2. Downloads and installs the latest NoMachine server.
	// 3. Sets a password for the 'vscode' user so you can log in.
	// 4. Installs Docker and the Warp terminal.
	"postCreateCommand": "sudo apt-get update && sudo apt-get install -y xfce4 xfce4-goodies dbus-x11 wget && sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/* && wget [https://download.nomachine.com/download/8.12/Linux/nomachine_8.12.12_1_amd64.deb](https://download.nomachine.com/download/8.12/Linux/nomachine_8.12.12_1_amd64.deb) -O /tmp/nomachine.deb && sudo dpkg -i /tmp/nomachine.deb && sudo rm /tmp/nomachine.deb && echo 'vscode:devpod' | sudo chpasswd && sudo apt-get update && sudo apt-get install -y docker.io gpg && wget -qO- [https://apt.warp.dev/key.asc](https://apt.warp.dev/key.asc) | sudo gpg --dearmor -o /usr/share/keyrings/warp.gpg && echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/warp.gpg] [https://apt.warp.dev/](https://apt.warp.dev/) stable main' | sudo tee /etc/apt/sources.list.d/warp.list && sudo apt-get update && sudo apt-get install -y warp-terminal",

	// Optional: Add VS Code extensions you want to be pre-installed.
	"customizations": {
		"vscode": {
			"extensions": [
				"ms-azuretools.vscode-docker",
				"GitHub.copilot"
			]
		}
	},

	// Run as the 'vscode' user. The base image creates this user for us.
	"remoteUser": "vscode"
}
```

### Step 3: Launch the Workspace
Now you are ready to launch your new cloud desktop on a cx42 instance.

Open your terminal and navigate into the folder containing your devcontainer.json file.

Run the devpod up command, specifying the provider and the exact machine type:

```Bash

# The --machine-type flag ensures DevPod provisions a Hetzner cx42 instance.
devpod up . --provider my-hetzner --machine-type cx42
```

DevPod will now:

- Connect to Hetzner and provision a cx42 VM.
- Install a container runtime on the VM.
- Build and start your dev container, running the long postCreateCommand to set everything up.
- Forward port 4000 to your local machine.

This process will take 5-10 minutes on the first launch. Subsequent starts will be much faster.

### Step 4: Connect to Your GUI Desktop
Once devpod up is finished, your cloud desktop is running and waiting.

1. Open the NoMachine Enterprise Client on your local computer.
2. Click "Add a new connection".
3. Leave the Protocol as NX and click Continue.
4. For the Host, enter localhost. The port should be 4000. Click Continue.
5. Leave the configuration method as Password. Click Continue.
6. Leave the proxy setting as Don't use a proxy. Click Continue.
7. Give the connection a name (e.g., "DevPod Hetzner") and click Done.
8. Double-click your new connection. You will be prompted for credentials:
  - Username: vscode
  - Password: devpod (or whatever you set in the devcontainer.json)
9. NoMachine will connect and show you some initial help dialogs. After clicking through them, you will see your full XFCE Linux desktop. It will be significantly smoother and more responsive than VNC.

### Step 5: Using Your Environment
You are now working inside a container on a powerful cloud VM.

Open the Terminal Emulator to get a shell.

Run warp-terminal to launch the Warp terminal you installed.

Run sudo docker ps to check that Docker is running.

If you use VS Code, you can connect it to the running devcontainer for a seamless file editing experience while you run GUI tools on the desktop.

### Step 6: Managing Costs (Stop & Start)
This is the most important step for cost savings.

**To Stop Your Workspace:**

When you are done working, go back to your local terminal and run devpod down:

```Bash

# This command finds the running workspace and shuts down the associated cloud VM.
# You will stop incurring compute costs immediately.
devpod down Cloud-Desktop-NoMachine
```
Your data and all installations are preserved on the VM's persistent disk, which costs very little to keep.

**To Resume Your Workspace:**

When you want to start working again, simply run devpod up again for that workspace:

```Bash
devpod up Cloud-Desktop-NoMachine
```

DevPod will find the existing VM, power it on, and reconnect everything. You'll be back in your high-performance desktop in just a minute or two.

