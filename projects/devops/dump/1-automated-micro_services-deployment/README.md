# Automated Micro-Services Deployment on Low-Cost EC2 with Docker Compose & Prometheus

Difficulty: 🟢 Easy

Primary Tools: AWS, Terraform, Docker Compose, Ansible, Prometheus, Node Exporter

Estimated Cost: $0.00 (100% AWS Free Tier compliant)
Time to Complete: 2–3 hours

## 🏢 Scenario & Architectural Design

Your team needs to quickly spin up a lightweight staging environment for a legacy microservice application. Management wants to avoid the overhead, complexity, and steep costs of managing a full-blown Kubernetes cluster (like EKS) or an AWS Application Load Balancer for this small project.

As the CloudOps Engineer, you are tasked with designing a self-contained, automated architecture on a single, hardened EC2 instance. The infrastructure must be provisioned via Terraform, configured using an Ansible playbook, run its application services via Docker Compose, and track its own system health via Prometheus. To keep the project completely free, all infrastructure must fit safely within the AWS Free Tier limitations.

## 📐 Logical Architecture Diagram (ASCII format)

```text
                      [ Public Internet ]
                              │ (HTTP - Port 80)
                              ▼
┌─────────────────────── AWS Cloud ───────────────────────────┐
│                                                             │
│  Default VPC / Public Subnet                                │
│  ┌─────────────────── EC2 Instance ──────────────────────┐  │
│  │                   (t3.micro / Ubuntu)                 │  │
│  │                                                       │  │
│  │  [ Security Group ]                                   │  │
│  │   ├── Inbound: 22 (SSH), 80 (App), 9090 (Prometheus)  │  │
│  │                                                       │  │
│  │  [ Docker Engine Container Runtime ]                 │  │
│  │   │                                                   │  │
│  │   ├───► Web App Container (Port 80:80)                │  │
│  │   │                                                   │  │
│  │   ├───► Prometheus Container (Port 9090:9090)         │  │
│  │   │       │                                           │  │
│  │   │       └─► Scrapes (Port 9100)                     │  │
│  │   │                                                   │  │
│  │   └─► Node Exporter Container (Port 9100:9100)        │  │
│  │                                                       │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘

```

## 🎯 Learning Objectives & Skill Targets

* **Declarative Infrastructure:** Write and execute dry-run validations with Terraform to provision computational resources on AWS.
* **Idempotent Configuration:** Author Ansible playbooks to update system packages, install the Docker engine daemon, and handle users safely.
* **Container Orchestration:** Define multi-container runtime dependencies using native Docker Compose YAML syntax.
* **Pull-Based Monitoring:** Configure a Prometheus server scrapeline targeting bare-metal metrics exported via Node Exporter.

## 💰 Frugal Ops: Cost Optimization Strategy

To guarantee that this deployment results in zero financial charges, the system enforces the following architecture constraints:

* **Compute:** Leverages a single `t2.micro` (or `t3.micro` depending on region availability) instance, maximizing the 750 hours/month tier allocation.
* **Storage:** Restricts the Elastic Block Store (EBS) root volume allocation strictly to `20 GB` utilizing modern `gp3` storage performance modifiers to prevent legacy `gp2` IOPS penalties without violating the 30 GB free storage envelope.
* **Networking:** Avoids Managed NAT Gateways entirely by binding the compute cluster to a public routing tier utilizing security filters to mimic safe access points.

---

## 🛠️ The Implementation Requirements

### 1. Cloud Infrastructure (Terraform & AWS)

Create a Terraform configuration (`main.tf`, `variables.tf`, `outputs.tf`) targeting the following assets:

* **AMI Source:** Filter dynamically for the latest stable Ubuntu 24.04 LTS Release.
* **Compute:** One `t3.micro` instance with a public IPv4 mapping allowed.
* **Storage Layer:** Root volume set explicitly to 20GB, type `gp3`.
* **Networking Security:** A dedicated Security Group exposing:
* Inbound TCP Port `22` matching your specific local `/32` public workspace mask.
* Inbound TCP Port `80` allowed from anywhere (`0.0.0.0/0`).
* Inbound TCP Port `9090` allowed from anywhere (`0.0.0.0/0`) to verify your telemetry metrics dashboard.



### 2. Configuration & Orchestration (Ansible & Docker)

Create an Ansible playbook (`deploy.yml`) accompanied by a basic local inventory file targeting your new EC2 public endpoint. The playbook must execute sequentially to accomplish the following tasks:

* Update the host package manager cache and establish vital system dependencies (`apt-transport-https`, `ca-certificates`, `curl`, `gnupg`).
* Incorporate the official upstream Docker GPG verification key and package repository coordinates.
* Install the latest package builds for `docker-ce`, `docker-ce-cli`, and `containerd.io`.
* Ensure the default remote system execution user (`ubuntu`) is added to the system `docker` execution group to enable passwordless runtime access.
* Drop a `docker-compose.yml` multi-container definition file onto the host system containing three integrated service runtimes:
1. **web_app:** Using the public `nginxdemos/hello` simple container image, mapping host interface port `80` directly to container network interface port `80`.
2. **node_exporter:** Using the official image `prom/node-exporter:v1.8.0`, exposing host metric endpoint port `9100`.
3. **prometheus:** Using the official engine image `prom/prometheus:v2.51.0`, pinning internal system port configuration to host map `9090`.



### 3. Observability & Operations (Monitoring Setup)

Your Ansible workspace must provision a native `prometheus.yml` runtime settings file structure inside the host instance engine directory. Ensure the configuration defines a scrape targets list pointing to your Node Exporter engine:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node_metrics'
    static_configs:
      - targets: ['node_exporter:9100']

```

---

## 🚨 Operational Troubleshooting Inject (Live Fire Exercise)

### Failure Scenario

After initializing the entire Ansible workflow blueprint without execution failures, you navigate to your public instance dashboard on port `9090` to observe your monitoring cluster status.

When navigating to the **Status -> Targets** UI dashboard view, the `node_metrics` target lists an explicit red-flag status condition indicating `DOWN`. The error code output points directly toward an infrastructure connection problem: `context deadline exceeded` or `connection refused`.

### Debugging Commands & Clues

Execute the following verification patterns sequentially to dissect the operational issue within the instance command shell:

1. Validate whether the target micro-services container instances are running properly:
```bash
docker ps -a

```


2. Verify if the Docker containers are listening correctly on the expected network interfaces:
```bash
ss -tulnp | grep -E "9090|9100"

```


3. Inspect the live container execution log outputs from the engine daemon process:
```bash
docker logs <insert_your_prometheus_container_id_here>

```



### Root Cause Hint

Review the networking configuration parameters defined in your docker composition manifests. If your Prometheus service configuration block is trying to pull metrics directly via a literal target string reference named `localhost:9100`, it will try to find that socket *inside its own isolated network container layer* instead of routing to the neighboring container engine.

To fix this, make sure both components share the same virtual Docker bridge network space, or update your target query format to point directly to the service descriptor key name: `node_exporter:9100`.

---

## ✅ Acceptance Criteria & Proof of Success

### Infrastructure Deploy

Executing a dry-run state review using the CLI binary matches current cloud infrastructure states perfectly:

```bash
terraform plan
# Output states must show zero elements to add, alter, or remove.

```

### Configuration Verified

Your Ansible verification tracking process returns successfully without any execution tracking drops:

```bash
ansible-playbook -i inventory deploy.yml --check
# Verification report must return changed=0 failed=0 outputs.

```

### Service & Metric Verification

You can reach your app metrics remotely using regular HTTP web requests. Running a basic curl test returns clean raw system metrics text from your deployment:

```bash
curl -s http://<YOUR_EC2_PUBLIC_IP>:9090/api/v1/targets | json_pp

```

**Expected JSON Response Snippet:**

```json
{
   "status" : "success",
   "data" : {
      "activeTargets" : [
         {
            "health" : "up",
            "labels" : {
               "instance" : "node_exporter:9100",
               "job" : "node_metrics"
            },
            "scrapeUrl" : "http://node_exporter:9100/metrics"
         }
      ]
   }
}

```

---

## 🧹 Cost-Aware Clean Up Process

To avoid any unexpected charges on your AWS billing console, tear down all resources by following these steps:

1. Instruct Terraform to destroy all active infrastructure components created during this lab module:
```bash
terraform destroy -auto-approve

```


2. Manually verify your active AWS regional dashboard settings to ensure the EC2 computing blocks, block storage attachments, and security groups are completely removed.