# Multi-Stage Docker Builds and Kubernetes Deployment Pod Anatomy Lab

Difficulty: 🟢 Easy to 🟡 Medium

Primary Tools: AWS, Terraform, Docker, K3s (Lightweight Kubernetes), Linux (Ubuntu), Spot Instances

Time to Complete: 2–3 hours

## 🏢 Scenario & Architectural Design

When moving from beginner Docker to production Kubernetes, junior engineers often struggle with two critical real-world concepts: **optimizing container images** and **understanding how containers share resources inside a Kubernetes Pod**.

In production, you never ship a container that includes your entire source code compiler, build tools, or package managers. Doing so creates massive, insecure container images. Instead, companies use **Multi-Stage Docker Builds** to compile the application in a temporary "builder" container, and then copy *only* the finished, compiled application into a tiny, secure production container.

Once shipped to Kubernetes, that container runs inside a **Pod**. A Pod is not just a wrapper around a container; it is an environment where multiple containers can run side-by-side (like an application container and a local storage or logging container) sharing the exact same network namespace and storage volumes.

In this lab, you will write a multi-stage Dockerfile by hand to build a minimal web page server. Then, you will provision a low-cost AWS Spot Instance, install K3s, and deploy a custom Kubernetes Pod manifest that forces you to inspect how shared storage works between an application container and an administrative container inside the same Pod boundary.

## 📐 Logical Architecture Diagram (ASCII format)

```text
       [ Your Local Machine / Workspace ]
                       │
                       │ (Builds optimized Multi-Stage Docker Image)
                       ▼
┌─────────────────────────── AWS Cloud ───────────────────────────┐
│                                                                 │
│  Default VPC / Public Subnet                                    │
│  ┌─────────────────────── EC2 Instance ──────────────────────┐  │
│  │                 (t3.micro or t3.small / Spot)             │  │
│  │                                                           │  │
│  │  [ Security Group ]                                       │  │
│  │   └── Inbound: 22 (SSH), 30080 (App NodePort)             │  │
│  │                                                           │  │
│  │  [ K3s Single-Node Kubernetes Cluster ]                   │  │
│  │   └── [ Kubernetes Pod Boundary: "web-logging-pod" ]     │  │
│  │        │                                                 │  │
│  │        ├── Container 1: Web Server (Port 80)              │  │
│  │        │    └── Writes logs to: /var/log/nginx/          │  │
│  │        │                             │                   │  │
│  │        │                             ▼ (Shared Volume)   │  │
│  │        ├── Volume: "shared-logs" ◄───┘                   │  │
│  │        │                             ▲                   │  │
│  │        │                             │ (Reads logs)      │  │
│  │        └── Container 2: Log Viewer ──┘                   │  │
│  │             └── Running customized Bash loop script       │  │
│  │                                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

```

## 🎯 Learning Objectives & Skill Targets

* **Multi-Stage Containerization:** Write optimized Dockerfiles that separate building environments from production runtimes.
* **Pod-Level Co-Scheduling:** Understand how multiple containers coordinate, share disk volumes, and operate inside a single Kubernetes Pod definition.
* **Manual Cluster Operations:** Execute direct `kubectl` interaction patterns to inspect containers, read multi-container logs, and troubleshoot runtime lifecycles.
* **Infrastructure as Code Integration:** Deploy a vanilla Linux runtime instance using Terraform Spot configurations to receive container environments.

---

## 🛠️ The Implementation Requirements

### 1. Cloud Infrastructure (Terraform & AWS)

Create a Terraform directory with your base configuration (`main.tf`, `outputs.tf`):

* Configure a single AWS EC2 instance running Ubuntu 24.04 LTS. Request a `t3.micro` or `t3.small` as an **AWS Spot Instance** to minimize billing costs.
* Attach a Security Group allowing inbound TCP port `22` (for SSH administration) and inbound TCP port `30080` (the custom NodePort we will use to visit our application).
* Provide a basic `user_data` script to automatically handle the baseline installation of Docker and K3s so the node is immediately ready to handle your manifests:
```bash
#!/bin/bash
sudo apt-get update -y
sudo apt-get install -y docker.io
curl -sfL https://get.k3s.io | sh -s - --disable traefik
sleep 20
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

```



### 2. Manual Multi-Stage Dockerfile (No AI Assist)

To understand how production images are stripped of clutter, write a file named `Dockerfile` completely by hand. Do not let an AI tool fill this out.

Your Dockerfile must implement exactly **two distinct stages**:

* **Stage 1: The Build Environment**
1. Start from an official heavy image: `FROM ubuntu:24.04 AS builder`
2. Run package managers to install a text modification utility: `RUN apt-get update && apt-get install -y sed`
3. Create a basic working folder inside the builder container (`/app`).
4. Write or copy a simple raw text string into a file named `raw_index.html` that reads: `<h1>Welcome to Devops Staging Environment</h1>`.
5. Use a standard `sed` command to modify the text inline, changing the word `Devops` to uppercase `DEVOPS`, and saving the output into a finalized file called `index.html`.


* **Stage 2: The Slim Production Environment**
1. Start from a completely fresh, lightweight container image: `FROM nginx:alpine`
2. Use the `COPY --from=builder` parameter to pull *only* the finalized `/app/index.html` out of your Stage 1 container, dropping it directly into Nginx's public HTML server directory (`/usr/share/nginx/html/index.html`).



*Once written, log into your EC2 instance, save your file, and build it locally using `docker build -t local-optimized-web:v1 .` to ensure your multi-stage instructions run cleanly.*

### 3. Kubernetes Pod Anatomy Manifest (Shared Volumes)

Now that you understand container isolation, you will write a Kubernetes manifest to learn how containers can break that isolation when placed together inside a Pod.

Create a file named `pod-manifest.yaml` on your server. Write a declaration that defines a single **Pod** holding **two separate containers** sharing one tracking volume:

* **The Core Pod Infrastructure:**
* Define an internal shared memory/disk space using a Kubernetes `emptyDir` volume named `shared-logs`.


* **Container #1: `web-server**`
* Use your locally built image `local-optimized-web:v1` (Set `imagePullPolicy: Never` so Kubernetes reads your local image cache).
* Inside this container, mount the `shared-logs` volume directly to Nginx's logging directory: `/var/log/nginx/`


* **Container #2: `log-monitor**`
* Use a simple, lightweight base image like `alpine:latest`.
* Inside this container, mount that exact same `shared-logs` volume to an internal folder named `/app/logs/`.
* **Your Custom Script Task:** Define a manual startup command block (`command` and `args` lists) inside this container configuration to execute a continuous bash/sh loop shell command. The loop must read the shared log file every 5 seconds and echo it out to standard output:
`while true; do if [ -f /app/logs/access.log ]; then tail -n 1 /app/logs/access.log; fi; sleep 5; done`


* **The Service Mapping:**
* Add a Kubernetes `Service` declaration below your Pod manifest. Set its type to `NodePort`, routing public traffic from incoming node port `30080` directly to the `web-server` container on port `80`.



Apply your complete configuration file into your live K3s cluster node environment:

```bash
kubectl apply -f pod-manifest.yaml

```

---

## 🚨 Operational Troubleshooting Inject (Live Fire Exercise)

### Failure Scenario

You successfully apply your manifest to the cluster. Running `kubectl get pods` shows that your Pod is stuck in a frustrating loop state displaying either `CrashLoopBackOff` or `RunContainerError`. Inspecting the status parameters indicates that the first container (`web-server`) is completely healthy, but the second container (`log-monitor`) is repeatedly dying.

### Debugging Actions & Clues

When working with multiple containers in a single Pod, standard commands can fail if you don't target the specific container you want to debug. Use these specific variations to investigate the container failure:

1. Request the diagnostic status reports for each specific container named inside the Pod definition:
```bash
kubectl describe pod web-logging-pod

```


2. Fetch the engine runtime log feed from the specific container that is failing:
```bash
kubectl logs web-logging-pod -c log-monitor

```


3. Test if you can drop into an interactive command shell inside the working container to explore the shared storage paths:
```bash
kubectl exec -it web-logging-pod -c web-server -- sh

```



### Root Cause Hint

Look closely at the image configuration declared for your `log-monitor` container. If you boot a vanilla Linux image like `alpine` or `ubuntu` without providing a long-running foreground command loop (or if your custom shell script contains a syntax error that causes it to exit immediately), the container will finish its process and shut down. Because Kubernetes expects containers to run indefinitely, it sees a stopped container as a crash and will continuously restart it, forcing the Pod into a `CrashLoopBackOff` loop. Ensure your loop script syntax is flawless and does not exit!

---

## ✅ Acceptance Criteria & Proof of Success

### Multi-Stage Build Verified

Run the image listing command on your server to confirm that your build successfully created an optimized, low-footprint image:

```bash
docker images local-optimized-web:v1
# The size footprint output should be remarkably small (~20MB to 30MB total) because the heavy build tools from Stage 1 were completely left behind.

```

### Pod Cluster Sync Verified

Check your Kubernetes cluster resources to verify that both containers are concurrently active and running inside the single Pod boundary:

```bash
kubectl get pods

```

**Expected Terminal Output:**

```text
NAME              READY   STATUS    RESTARTS   AGE
web-logging-pod   2/2     Running   0          4m

```

*(Note the `2/2` column, proving both containers are concurrently active inside that Pod).*

### Pod Interaction & Shared Volume Verification

Trigger a web request to your custom NodePort to generate traffic logs:

```bash
curl http://localhost:30080

```

Now, check the logs of your second container (`log-monitor`). Because the two containers share the same volume, your second container should instantly see and print out the web traffic generated by the first container:

```bash
kubectl logs web-logging-pod -c log-monitor

```

**Expected Log Stream Response:**

```text
127.0.0.1 - - [24/Jun/2026:17:15:32 +0000] "GET / HTTP/1.1" 200 48 "-" "curl/7.81.0"

```

---

## 🧹 Cost-Aware Clean Up Process

*A brief reminder regarding your lab maintenance:*

1. To completely remove all active cloud assets and ensure no unexpected fees appear on your AWS account, execute the cleanup command inside your local machine's project directory:
```bash
terraform destroy -auto-approve

```


2. Double-check your AWS web console's EC2 instance area to ensure your spot instance instance states are showing as completely terminated.