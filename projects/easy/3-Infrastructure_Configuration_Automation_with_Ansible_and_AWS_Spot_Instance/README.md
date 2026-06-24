# Infrastructure Configuration Automation with Ansible and AWS Spot Instances

Difficulty: 🟢 Easy

Primary Tools: AWS, Terraform, Ansible, Linux (Ubuntu), Bash Scripting

Estimated Cost: ~$0.015 per hour (~$0.05 total for a 2-hour lab using an AWS Spot Instance)

Time to Complete: 2–3 hours

## 🏢 Scenario & Architectural Design

In your previous tasks, you used Terraform to build an environment and utilized a cloud-native `user_data` script to automatically configure the server upon booting up. While `user_data` works well for very simple single-instance setups, it falls short in real engineering environments. If a configuration breaks, you have to completely tear down and recreate the entire server.

To solve this, companies use dedicated **Configuration Management** tools. The undisputed industry standard is **Ansible**.

Ansible allows you to write clean, repeatable automation files (called Playbooks) that configure your servers after they are already running. If a setting changes, you simply re-run your Ansible playbook on the live machine without deleting your server.

In this scenario, you will provision a low-cost AWS Spot Instance using Terraform. Instead of using a startup script to install your software, you will leave the server completely blank. You will then write a custom Ansible Playbook from scratch to securely log into that instance, configure a production-ready web application environment, and set up a custom system maintenance script.

## 📐 Logical Architecture Diagram (ASCII format)

```text
       [ Your Local Machine / Laptop ]
                    │
                    │ (Executes Ansible Playbook over SSH)
                    ▼
┌─────────────────────────── AWS Cloud ───────────────────────────┐
│                                                                 │
│  Default VPC / Public Subnet                                    │
│  ┌─────────────────────── EC2 Instance ──────────────────────┐  │
│  │                 (t2.micro or t3.micro / Spot)             │  │
│  │                                                           │  │
│  │  [ Security Group ]                                       │  │
│  │   └── Inbound: 22 (SSH), 80 (HTTP)                        │  │
│  │                                                           │  │
│  │  [ Inside Ubuntu Operating System ]                       │  │
│  │   ├── Packages: Apache2 Web Server (Port 80)              │  │
│  │   │                                                       │  │
│  │   └── Directory: /usr/local/bin/                          │  │
│  │         └── [ Your Custom Backup Bash Script ]            │  │
│  │                                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

```

## 🎯 Learning Objectives & Skill Targets

* **Agentless Configuration Management:** Understand how Ansible connects to and configures remote Linux nodes securely via standard SSH.
* **Writing Idempotent Playbooks:** Author structured Ansible tasks to manage packages, template files, and system file structures.
* **Bare-Metal Linux Scripting:** Create and integrate customized Bash utilities directly into system administration routines.
* **Dynamic Cloud Provisioning:** Deploy bare operating systems ready to receive external configurations.

---

## 🛠️ The Implementation Requirements

### 1. Cloud Infrastructure (Terraform & AWS)

Create a Terraform project folder holding your `main.tf` and `outputs.tf` configurations:

* **Compute shape:** Define a single `t2.micro` or `t3.micro` instance. Ensure it is configured as an **AWS Spot Instance** inside your resource options block to keep costs below two cents per hour.
* **Network Enclosure:** Attach a standard Security Group exposing inbound port `22` (restricted to your workstation) and inbound port `80` (open to the public).
* **Important Change:** Do **NOT** provide any bash commands inside the `user_data` block. The instance must boot into a completely blank, vanilla Ubuntu 24.04 LTS state.

### 2. Manual Bash Script Assignment (No AI Assist)

To truly learn how Linux management works, you will write a system automation script entirely by hand. Create a local file on your computer named `system_backup.sh`.

Write a script that executes the following tasks step-by-step:

1. Defines a variable pointing to a backup target folder: `/var/backups/web_backup`
2. Checks if that folder exists on the operating system; if it doesn't, create it using standard directory commands.
3. Packages the web server's core content folder located at `/var/www/html/` into a compressed `.tar.gz` archive.
4. Saves that archive inside your backup target directory using a dynamically generated filename that contains the current system timestamp (e.g., `web-backup-2026-06-24.tar.gz`).

### 3. Configuration Automation Layer (Ansible)

Now, create an Ansible setup inside your directory to push your custom script and install your web application environment. Create two files:

**`hosts.ini` (Your Inventory File)** Create a basic inventory file containing your server connection info. Replace the placeholder values with your live server details:

```ini
[webservers]
my_cloud_server ansible_host=YOUR_EC2_PUBLIC_IP_ADDRESS

[webservers:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/your_aws_private_key.pem

```

**`playbook.yml` (Your Automation Steps)** Write your Ansible playbook step-by-step to handle the environment configuration. Try to write out these YAML lines by hand to build your familiarity with Ansible's structure:

* **Target & Privileges:** Set `hosts: webservers` and include `become: yes` so Ansible executes operations with administrative (`sudo`) root clearance.
* **Task 1: Package Synchronization:** Use Ansible's built-in `apt` module to run an update on the system package database cache and install the `apache2` web server package.
* **Task 2: Service Verification:** Use Ansible's `service` module to ensure that the Apache server is actively running and scheduled to automatically turn on if the machine reboots.
* **Task 3: Custom Script Delivery:** Use Ansible's `copy` module to transfer your locally written `system_backup.sh` file from your laptop directly onto the server at `/usr/local/bin/system_backup.sh`. Crucially, set the file `mode: '0755'` so the script has executable permissions.

Run your playbook using the following terminal command on your machine:

```bash
ansible-playbook -i hosts.ini playbook.yml

```

---

## 🚨 Operational Troubleshooting Inject (Live Fire Exercise)

### Failure Scenario

You type out your playbook, save the files, and execute the `ansible-playbook` command in your terminal. However, the execution instantly halts before finishing any tasks. The terminal displays a bright red fatal error message stating: `UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh", "unreachable": true}`.

### Debugging Actions & Clues

When working with Ansible, connection failures are almost always related to basic networking or access credentials. Run these commands directly inside your terminal window to track down the root cause:

1. Test if your machine can communicate with the server over the network using a standard ping test:
```bash
ping <YOUR_EC2_PUBLIC_IP>

```


2. Attempt to bypass Ansible completely and log into the server manually using standard SSH:
```bash
ssh -i ~/.ssh/your_aws_private_key.pem ubuntu@<YOUR_EC2_PUBLIC_IP>

```


3. Read your local Ansible inventory file (`hosts.ini`) carefully to verify that the path to your secret private key file matches its exact location on your computer.

### Root Cause Hint

If manual SSH fails with a "Connection timed out" error, check your AWS web console. The most likely culprit is that your public IP address changed, causing the AWS Security Group to block your incoming connections on port `22`. If manual SSH works perfectly but Ansible still fails, look closely at your `hosts.ini` syntax. A misspelled parameter name or an incorrect relative path to your private key file will prevent Ansible from establishing an SSH connection.

---

## ✅ Acceptance Criteria & Proof of Success

### Infrastructure Deploy

Run your infrastructure deployment validation tool to prove your bare-metal server is online:

```bash
terraform output
# Must accurately output your cloud instance public IP parameters.

```

### Configuration Management Verified

Your terminal shows a completely clean, successful execution log from your Ansible deployment run:

```text
PLAY RECAP **********************************************************************************
my_cloud_server            : ok=4    changed=3    unreachable=0    failed=0    skipped=0

```

### Script Execution & Functionality Verification

Log into your EC2 server via SSH and manually execute your custom Bash backup script to prove it was written correctly and functions on the server:

```bash
sudo /usr/local/bin/system_backup.sh

```

Now, inspect the target backup directory on your server. You should see a freshly generated, compressed archive of your web configuration files:

```bash
ls -l /var/backups/web_backup/

```

**Expected Terminal Output:**

```text
-rw-r--r-- 1 root root 145 Jun 24 13:15 web-backup-2026-06-24.tar.gz

```

---

## 🧹 Cost-Aware Clean Up Process

*A brief reminder regarding your lab maintenance:*

1. To keep your AWS account clean and prevent any ongoing hourly billing charges, tear down all of your infrastructure resources by running this command in your project directory:
```bash
terraform destroy -auto-approve

```


2. Double-check your official AWS Web Console to ensure that your active Spot Request status is marked as closed.