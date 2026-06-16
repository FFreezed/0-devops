# 🚀 Frugal Multi-Container CI/CD Lab

This lab provisions a predictable, cost-optimized On-Demand AWS EC2 instance using Terraform, bootstraps it with Docker, and establishes a fully automated CI/CD deployment pipeline via GitHub Actions.

---

## 🏗️ Architecture Blueprint

The deployment workflow flows as follows:

1. **Local Machine (WSL):** Code updates (`index.html`) are pushed to GitHub.
2. **GitHub Actions:** Automatically triggers on a `main` branch push, logs into the EC2 instance via SSH, and pulls the fresh code.
3. **AWS EC2 (Docker Compose):** Rebuilds the lightweight Nginx Alpine container in the background.

---

## 🛠️ Step 1: Clone & Configure Infrastructure

1. Clone this repository to your local **Ubuntu WSL** environment.
2. Open `main.tf` and update the `my_local_ip` block with your current **Public WAN IP** (run `curl ifconfig.me` in WSL to find it):
```hcl
locals {
  my_local_ip = "YOUR_PUBLIC_IP/32" # <-- Change this
}

```



---

## ☁️ Step 2: Provision the Cloud

Run the following commands inside your project directory to spin up the infrastructure:

```bash
# Initialize Terraform providers
terraform init

# Deploy the infrastructure
terraform apply -auto-approve

```

> 📌 **Note:** Take note of the `instance_public_ip` output printed on your screen when complete.

---

## 🔒 Step 3: Configure GitHub Security Secrets

To allow GitHub to communicate with your cloud server securely, navigate to your online GitHub Repository -> **Settings** -> **Secrets and variables** -> **Actions**, and add these two secrets:

1. **`EC2_HOST`**: Paste the `instance_public_ip` from your Terraform output.
2. **`EC2_SSH_PRIVATE_KEY`**: Paste the *entire* text content of your local `.pem` private key file (including the `BEGIN` and `END` headers).

---

## 🚀 Step 4: Trigger the Pipeline

Now, push a change to trigger the automated deployment pipeline:

```bash
git add .
git commit -m "infrastructure: initial cluster setup"
git push origin main

```

Navigate to the **Actions** tab on GitHub to watch the live compilation. Once it completes successfully, open your web browser and navigate to your public web application endpoint:

```text
http://<YOUR_EC2_PUBLIC_IP>

```

---

## 🧠 Lessons Learned & Debugging Notes

If you are running this project or setting it up from scratch in the future, keep these core behaviors in mind:

* **The Security Timeout:** If your browser or SSH connections time out, your public IP has likely changed. Verify your WAN IP matches the firewall rule defined inside `main.tf`.
* **The User Data Race Condition:** When an instance first boots up, the script defined inside `user_data` handles the installation of Docker asynchronously. If GitHub Actions fires immediately on creation, it might try to execute commands before the Docker subsystem is initialized.
* **The Sudo Requirement:** Because the automation pipeline runs concurrently while group mapping occurs on initial boot, always use `sudo docker-compose` inside `.github/workflows/deploy.yml` to guarantee root socket privileges.
* **8GB Disk Cleanup:** To keep this lab running at a fraction of a cent on a tight 8GB volume, the pipeline enforces `sudo docker system prune -f` at the tail end of every execution to permanently wipe out dangling build cache layers.

---

## 🧹 Step 5: Clean Up (Avoid Charges)

When you are finished using the lab environment, always tear down your cloud resources completely to ensure you aren't billed for idle background compute usage:

```bash
terraform destroy -auto-approve

```