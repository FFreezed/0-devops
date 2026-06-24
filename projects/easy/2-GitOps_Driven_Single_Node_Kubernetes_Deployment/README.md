# GitOps-Driven Single-Node Kubernetes Deployment with K3s and ArgoCD

Difficulty: 🟢 Easy

Primary Tools: AWS, Terraform, K3s (Lightweight Kubernetes), ArgoCD, GitHub, Spot Instances

Estimated Cost: ~$0.015 - $0.02 USD per hour (~$0.06 total for a 3-hour lab)

Time to Complete: 2–3 hours

## 🏢 Scenario & Architectural Design

Now that you have mastered basic Docker and individual container orchestration, it is time to progress to the core pattern used by modern tech companies: **GitOps** and **Kubernetes (K8s)**. In enterprise environments, infrastructure teams rarely run raw `docker-compose` commands manually on production systems. Instead, they use Kubernetes to manage containers and a tool like **ArgoCD** to sync application states directly from a Git repository.

In this scenario, your goal is to build a modern, automated Kubernetes playground. Instead of paying massive fees for an enterprise AWS EKS cluster, you will use Terraform to request a low-cost AWS Spot Instance and deploy **K3s**—a lightweight, fully-compliant Kubernetes distribution that runs smoothly inside a single virtual machine.

Once your cluster is active, you will install ArgoCD inside it. ArgoCD will monitor a directory in your GitHub repository. The moment you push or update a Kubernetes deployment file in Git, ArgoCD will notice the change and pull down your application automatically.

## 📐 Logical Architecture Diagram (ASCII format)

```text
                                  [ GitHub Git Repository ]
                                  (Holds App Manifest Files)
                                              │
                                              │ (GitOps Pull Sync)
                                              ▼
┌─────────────────────────── AWS Cloud ───────────────────────────┐
│                                                                 │
│  Default VPC / Public Subnet                                    │
│  ┌─────────────────────── EC2 Instance ──────────────────────┐  │
│  │               (t3.micro or t3.small / Spot)               │  │
│  │                                                           │  │
│  │  [ Security Group ]                                       │  │
│  │   └── Inbound: 22 (SSH), 80 (HTTP), 8080 (ArgoCD UI)      │  │
│  │                                                           │  │
│  │  [ K3s Kubernetes Cluster Runtime Engine ]                │  │
│  │   ├── Namespace: argocd                                   │  │
│  │   │     └── [ ArgoCD Controller Pods ] ───────────────────┤  │
│  │   │                                                       │  │
│  │   └── Namespace: default                                  │  │
│  │         └── [ Web Application Pods ]                      │  │
│  │                                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

```

## 🎯 Learning Objectives & Skill Targets

* **Lightweight Kubernetes Orchestration:** Install and administer a compliant K3s cluster on a cloud-hosted Linux instance.
* **Declarative GitOps Principles:** Install and configure ArgoCD to automate continuous delivery from a Git repository state.
* **Kubernetes Component Authoring:** Write native Kubernetes `Deployment` and `Service` manifests.
* **Cloud Security Mapping:** Expose isolated Kubernetes service entry points through cloud security infrastructure.

## 🛠️ The Implementation Requirements

### 1. Cloud Infrastructure (Terraform & AWS)

Create your Terraform working directory containing `main.tf` and `outputs.tf` to build the core system:

* **Compute:** One `t3.small` AWS instance configured as a Spot Instance to lock in low rates.
* **Security Group Rules:** Expose the following ports:
* Inbound TCP Port `22`: For direct SSH maintenance access.
* Inbound TCP Port `8080`: To access the visual ArgoCD management dashboard interface.
* Inbound TCP Port `80`: To access your deployed web application.



### 2. Cluster Bootstrapping & Installation (User Data)

Attach a startup script inside your Terraform script's `user_data` section to automatically spin up your Kubernetes environment when the machine turns on:

```bash
#!/bin/bash
sudo apt-get update -y

# 1. Install K3s and natively configure group read permissions for the config file
curl -sfL https://get.k3s.io | sh -s - --disable traefik --write-kubeconfig-mode 644

# 2. Wait a few seconds for the file system layers to settle
sleep 15

# 3. Create the home config path for the ubuntu user safely
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config

# 4. Correct the file ownership explicitly
chown -R ubuntu:ubuntu /home/ubuntu/.kube
chmod 600 /home/ubuntu/.kube/config

# 5. Permanently append the KUBECONFIG environment variable path to the profile shell
echo "export KUBECONFIG=/home/ubuntu/.kube/config" >> /home/ubuntu/.bashrc

```

Note : This section script it fixed/revised

### 3. GitOps Setup (ArgoCD Deployment)

Once your server is live and you log in via SSH, install ArgoCD into its own dedicated area within your new cluster:

```bash
# Create a dedicated namespace for ArgoCD components
kubectl create namespace argocd

# Apply the official upstream stable ArgoCD manifest deployment
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

```

To access the ArgoCD management screen from your web browser, convert the internal service block into a publicly accessible `NodePort` mapping to port `8080`:

```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"port": 80, "targetPort": 8080, "nodePort": 30080}]}}'

```

*(You will then need to run a background port-forward loop command like `kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0 &` to access the console using your instance's public IP address at `http://<IP>:8080`).*

Note : This section script it fixed/revised

### 4. Git Application Configuration Manifests

Create a folder named `k8s` inside a public repository on your GitHub account. Inside this directory, create a manifest file named `app.yaml` that defines your application:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-web-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30000

```

Now, navigate to your ArgoCD web portal UI, create a **New App**, and point it directly to your GitHub repository URL and the `k8s` path. Enable the **Auto-Sync** option!

---

## 🚨 Operational Troubleshooting Inject (Live Fire Exercise)

### Failure Scenario

You successfully add your application directory into your ArgoCD dashboard. The dashboard tile initially turns green, showing a successful sync state. However, when you enter your EC2 instance's public IP address on standard web port `80`, your browser displays an error stating the site can't be reached.

### Debugging Commands & Clues

Log directly into your K3s cluster master instance using your terminal shell and run these diagnostic commands:

1. List all running pods across the default namespace to confirm they are active:
```bash
kubectl get pods

```


2. Check the configuration details of your application service mapping:
```bash
kubectl get svc nginx-service

```


3. Look for errors or event issues inside your cluster components:
```bash
kubectl get events --sort-by='.metadata.creationTimestamp'

```



### Root Cause Hint

Look closely at your `Service` definition file inside your Git repository. It is configured to route traffic on `nodePort: 30000`. When working with standard Kubernetes configurations, mapping an application straight to port `80` requires an active Ingress controller or cloud load balancer. If you are targeting a direct node network map, you must browse to your specific assigned NodePort instead: `http://<YOUR_EC2_PUBLIC_IP>:30000`. Alternatively, update your security group settings in AWS to ensure port `30000` is open to incoming web traffic.

---

## ✅ Acceptance Criteria & Proof of Success

### Infrastructure Deploy

Confirm your K3s control plane is up and running correctly on your cloud instance:

```bash
kubectl get nodes

```

**Expected Output:**

```text
NAME           STATUS   ROLES                  AGE   VERSION
ip-172-x-x-x   Ready    control-plane,master   5m    v1.x.x+k3s1

```

### GitOps Sync Verified

Your ArgoCD web panel dashboard interface displays a healthy green state indicator showing that your `nginx-web-app` matches your Git repository perfectly.

### Application Verification

Query the application endpoint locally from within your system shell to verify that your cluster's pods are successfully processing live traffic requests:

```bash
curl -I http://localhost:30000

```

The console output must return a clean response showing an HTTP header profile containing `HTTP/1.1 200 OK`.

---

## 🧹 Cost-Aware Clean Up Process

Because this cluster runs outside of the AWS Free Tier, it is critical to tear down your resources immediately when you finish practicing to avoid unexpected charges.

1. In your local terminal workspace, run the global infrastructure destruction routine:
```bash
terraform destroy -auto-approve

```


2. Log into the official web-based AWS Management Console, navigate to the **EC2 Dashboard**, and confirm that your active compute instances and Spot Requests are completely removed.