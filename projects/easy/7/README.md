# Secure CI/CD Artifact Pipelines with HashiCorp Vault and Managed Container Registries

Difficulty: 🟢 Easy to 🟡 Medium

Primary Tools: AWS, Terraform, Docker, GitHub Actions, HashiCorp Vault, AWS ECR (Elastic Container Registry), Spot Instances

Time to Complete: 2–3 hours

## 🏢 Scenario & Architectural Design

In your previous task, you built an optimized Docker image and pushed it directly to your server via an SSH-based pipeline. While that works for small, isolated projects, it introduces a major security risk: your deployment server becomes your build environment, and your private SSH keys or AWS API keys are often left sitting in plain text inside your GitHub Actions configurations.

In production environments, companies separate their workflows into three distinct boundaries:

1. **The Build Environment:** Code is built and packaged inside a clean CI/CD runner.
2. **The Container Registry:** Images are signed and stored inside a managed registry like **AWS ECR** (Elastic Container Registry) instead of being built directly on the server.
3. **The Secret Management Engine:** Sensitive data (like database passwords, API tokens, or registry keys) is never stored in GitHub or hardcoded into scripts. Instead, they are locked inside a dedicated tool like **HashiCorp Vault**, which hands out short-lived, encrypted tokens only when a container explicitly requests them.

In this scenario, you will use Terraform to request an AWS Spot Instance and automatically provision a secure HashiCorp Vault server. You will set up an AWS ECR repository to store application containers. To learn how modern security pipelines function, you will write a custom **Python Script entirely by hand** that authenticates against Vault's API, retrieves an encrypted secret key, and uses it to boot your application container securely.

## 📐 Logical Architecture Diagram (ASCII format)

```text
       [ Developer Push ] ───► [ GitHub Actions Runner ]
                                     │
                                     ├───► 1. Fetches Build Secrets via API
                                     │     from [ HashiCorp Vault Server ] (Port 8200)
                                     │
                                     └───► 2. Builds & Pushes Secure Docker Image
                                           to [ AWS ECR Repository ]
                                                     │
                                                     ▼
┌───────────────────────────────── AWS Cloud ─────────────────────────────────┐
│                                                                             │
│  Default VPC / Public Subnet                                                │
│  ┌───────────────────────────── EC2 Instance ────────────────────────────┐  │
│  │                       (t3.micro or t3.small / Spot)                   │  │
│  │                                                                       │  │
│  │  [ Security Group ]                                                   │  │
│  │   └── Inbound Ports: 22 (SSH), 8200 (Vault UI), 8080 (App)            │  │
│  │                                                                       │  │
│  │  [ Docker Engine Runtime ]                                            │  │
│  │   ├── Container 1: [ HashiCorp Vault Secret Engine ]                  │  │
│  │   │     └── Stores dynamic DB API tokens locked in memory             │  │
│  │   │                                                                   │  │
│  │   └── Container 2: [ Secure Web App Container ]                       │  │
│  │         │   └── Pulled down from AWS ECR registry                     │  │
│  │         └── Runs hand-written Python initialization check             │  │
│  │                                                                       │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘

```

## 🎯 Learning Objectives & Skill Targets

* **Centralized Secret Engine Administration:** Initialize, unseal, and manage key-value secret engines using HashiCorp Vault.
* **Managed Container Repositories:** Provision and manage private container registries using AWS ECR.
* **Programmatic Secret Retrieval:** Write production-grade Python scripts to communicate with tokenized REST APIs securely.
* **Decoupled CI/CD Packaging:** Build container workflows that completely separate building code from destination deployment hosts.

---

## 🛠️ The Implementation Requirements

### 1. Cloud Infrastructure (Terraform & AWS)

Create a Terraform directory with `main.tf` and `outputs.tf` assets:

* Configure a single AWS EC2 instance (`t3.micro` or `t3.small`) as an **AWS Spot Instance** to maintain low costs.
* Attach a Security Group exposing inbound TCP ports: `22` (SSH), `8200` (The official interactive web interface port for HashiCorp Vault), and `8080` (Your application server port).
* Add a new Terraform resource block to declare a managed private image repository using **AWS ECR**:
```hcl
resource "aws_ecr_repository" "app_repo" {
  name                 = "junior-devops-secure-app"
  image_tag_mutability = "MUTABLE"
}

```


* Include a baseline `user_data` script to automatically handle installing Docker and Docker Compose on boot.

### 2. Manual Vault Initialization & Token Setup

Once your server is live, use Docker Compose to spin up a standalone developer instance of HashiCorp Vault. Create a `docker-compose.yml` file on your server containing:

```yaml
version: '3.8'
services:
  vault:
    image: hashicorp/vault:1.15.0
    container_name: vault-server
    ports:
      - "8200:8200"
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: "my-secure-root-token-123"
      VAULT_DEV_LISTEN_ADDRESS: "0.0.0.0:8200"
    cap_add:
      - IPC_LOCK
    restart: always

```

Launch Vault using `docker-compose up -d`.

* Open your browser to `http://<YOUR_EC2_IP>:8200`, log in using your root token `my-secure-root-token-123`.
* Enable a new **KV (Key-Value) Secrets Engine** named `secret/`.
* Create a secret path named `app-config` and add a manual key-value pair inside it:
* Key: `DATABASE_PASSWORD`
* Value: `SuperSecretProductionPassword99!`



### 3. Hand-Written Python Secret Fetcher 

To practice interacting with modern cloud APIs, write a Python script named `app_init.py` completely by hand. Do not let an AI generate this file line-by-line.

Your script must implement the following routine:

1. Imports the standard `os`, `sys`, `time`, and third-party `requests` libraries.
2. Defines two configuration variables read from environment variables on the system: `VAULT_URL` (e.g., `http://<YOUR_EC2_IP>:8200`) and `VAULT_TOKEN` (your root token).
3. Constructs a structured HTTP GET request using `requests.get()` pointing to Vault's standard v1 REST API secret path:
`f"{VAULT_URL}/v1/secret/data/app-config"`
4. Includes the required secret header line so Vault authorizes the request: `headers = {"X-Vault-Token": VAULT_TOKEN}`.
5. Parses the returned JSON data to extract your hidden `DATABASE_PASSWORD`.
6. Prints out a clear validation statement to standard output: `"Successfully fetched credential from Vault engine! Processing server startup..."`.
7. Enters a standard infinite loop that acts as a simple web server or long-running app listening on port `8080`.

Wrap this script inside a simple `Dockerfile` that installs the `requests` library and executes your initialization app.

### 4. Continuous Integration Pipeline (GitHub Actions)

Create a workflow file inside your repository at `.github/workflows/build-pipeline.yml`. Write a workflow that triggers whenever code is pushed to your `main` branch:

1. Logs into your AWS account securely using repository secrets (`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`).
2. Authenticates your local runner terminal against your newly provisioned private **AWS ECR** registry.
3. Builds your custom container image locally on the runner using your hand-written Dockerfile.
4. Tags and pushes that secure image straight up into your cloud ECR repository link.

---

## 🚨 Operational Troubleshooting Inject (Live Fire Exercise)

### Failure Scenario

Your GitHub Actions pipeline executes with a completely green status, and your image is successfully uploaded to AWS ECR. You pull the image down to your server and run it. However, when you check your container's live runtime outputs using `docker logs`, the application crashes instantly with a long error message reading: `requests.exceptions.ConnectionError: HTTPConnectionPool(host='localhost', port=8200): Max retries exceeded with url`.

### Debugging Actions & Clues

When working with separated container structures, connection errors point to issues with network addressing or incorrect environment paths. Run these commands on your EC2 host machine:

1. Check if the Vault server is actively accepting external connections from other running applications:
```bash
curl http://localhost:8200/v1/sys/health

```


2. Inspect the configuration flags passed into your container application to see what environment variables it is reading:
```bash
docker inspect <your_running_app_container_id> | grep -A 10 "Env"

```


3. Test if your application container can communicate with the network host by executing an internal curl command directly inside the container namespace:
```bash
docker run --rm alpine curl -I http://vault-server:8200/v1/sys/health

```



### Root Cause Hint

Look closely at the `VAULT_URL` variable you provided to your container app. If your script passes a literal target address pointing to `http://localhost:8200`, the application container will look for Vault *inside its own container boundary* instead of routing to the neighboring Vault service container. To fix this, change your application's target environment variable to point to your machine's actual public EC2 IP address, or link both containers together inside a shared custom Docker bridge network space so they can talk directly using their container name strings (e.g., `http://vault:8200`).

---

## ✅ Acceptance Criteria & Proof of Success

### ECR Registry Verification

Verify that your automated build pipeline successfully pushed your code to the cloud repository by listing the active image items using the AWS CLI:

```bash
aws ecr describe-images --repository-name junior-devops-secure-app
# The terminal response must return a valid JSON description showing an active image size and tag metadata.

```

### Vault Storage Engine Verification

Query Vault's API engine directly via your terminal using your secure token to prove your data payload is saved safely:

```bash
curl -H "X-Vault-Token: my-secure-root-token-123" http://localhost:8200/v1/secret/data/app-config

```

The response body must output a clean JSON map containing your `DATABASE_PASSWORD` entry inside the configuration variables block.

### Application Initialization Verification

Launch your newly pulled container image from ECR on your server, ensuring you pass your Vault connection details as environment parameters. Check your log stream outputs:

```bash
docker logs <your_secure_app_container>

```

**Expected Output Log Stream:**

```text
Successfully fetched credential from Vault engine! Processing server startup...
Running application loop on interface port 8080...

```

---

## 🧹 Cost-Aware Clean Up Process

1. To avoid any unexpected charges outside of your learning budget, tear down all resources created by this project by running the global deletion routine in your project workspace:
```bash
terraform destroy -auto-approve

```


2. Navigate to your cloud provider web dashboard interface and manually check your **Elastic Container Registry (ECR)** dashboard to confirm that your testing image registry repository is completely removed.
