# DevOps Capstone Project — Visitor Counter on AWS EKS

A production-style deployment combining every skill from a 22-day DevOps learning journey into one real, working, end-to-end system.

**Live architecture demonstrated:** Route53 → Load Balancer (auto-provisioned by Kubernetes) → EKS (Frontend + Backend) → ElastiCache (Redis) + RDS (MySQL), fully automated with Terraform, deployed via Docker + Kubernetes, secured with least-privilege networking, and monitored via CloudWatch.

---

## 1. What This App Does

A deliberately simple "visitor counter" — every time someone loads the page, the count increases by one. The app itself is intentionally boring; the point of the capstone is the **infrastructure and deployment pipeline** around it, not the application logic.

- **Frontend:** static HTML + JavaScript, served by nginx, calls the backend API on load
- **Backend:** a small Flask API with three endpoints (`/api/visit`, `/api/count`, `/health`)
- **Redis (ElastiCache):** stores the live counter for fast reads/writes
- **RDS (MySQL):** provisioned as the system of record for persistent data (available for future features beyond the counter)

---

## 2. Architecture Diagram

```
                          User
                           │
                           ▼
                        Route 53 (DNS)
                           │
                           ▼
              AWS Load Balancer (auto-created by
              the Kubernetes "frontend-service")
                           │
                           ▼
                    ┌─────────────┐
                    │     EKS     │
                    │  (Kubernetes)│
                    └─────────────┘
                    /               \
                   /                 \
          Frontend (nginx)      Backend (Flask)
          2 replicas            2 replicas
                                     │
                          ┌──────────┴──────────┐
                          │                      │
                  Redis (ElastiCache)      RDS (MySQL)
                  cache.t3.micro           db.t3.micro
                  port 6379                port 3306
                  VPC-internal only        VPC-internal only

Monitoring: EKS control plane logging → CloudWatch
Security:   All resources in a private VPC (10.0.0.0/16),
            databases reachable ONLY from inside the VPC,
            least-privilege IAM roles for every component
```

---

## 3. How Traffic Actually Flows (step by step)

1. A user visits the site's address (the Load Balancer's DNS name, or a real domain pointed at it via Route53).
2. AWS's Load Balancer receives the request and forwards it to one of 2 healthy **frontend** pods running nginx.
3. nginx serves the static HTML/JS page. The page's JavaScript immediately calls `/api/visit`.
4. Because `/api/` is a special route in nginx's config, nginx **internally proxies** that specific request to `backend-service` — a Kubernetes Service reachable only from inside the cluster.
5. Kubernetes routes that internal request to one of 2 healthy **backend** pods running Flask.
6. Flask increments the counter in **Redis** (ElastiCache) and returns the new count.
7. The response travels back through the same path to the user's browser, which updates the page to show "You are visitor #N".

**Key security point:** the backend and both databases are never directly reachable from the public internet — only the frontend's Load Balancer is exposed. Everything else communicates over the private VPC network.

---

## 4. How Infrastructure Gets Created (Infrastructure as Code)

All infrastructure is defined in Terraform (`/terraform` folder) and built with a single command:

```bash
terraform apply
```

This creates, in order (Terraform resolves dependencies automatically):

| File | What it builds |
|---|---|
| `provider.tf` | Configures the AWS provider (region: ap-south-1) |
| `vpc.tf` | VPC (10.0.0.0/16), 2 public subnets across 2 Availability Zones, Internet Gateway, route table |
| `eks.tf` | EKS cluster (control plane) + its IAM role |
| `eks-nodes.tf` | EKS node group (2× `t3.small` worker nodes) + IAM roles for worker permissions |
| `rds.tf` | RDS MySQL instance, its own subnet group and security group (VPC-internal only) |
| `redis.tf` | ElastiCache Redis cluster, its own subnet group and security group (VPC-internal only) |

Tearing everything down is equally simple:

```bash
terraform destroy
```

**Important operational note:** because Kubernetes' `LoadBalancer` Service type creates an AWS Load Balancer that Terraform doesn't know about, that Service must be deleted with `kubectl delete` **before** running `terraform destroy` — otherwise the destroy operation can hang indefinitely waiting for a VPC that still has an untracked resource inside it.

---

## 5. How Deployment Happens

1. Docker images for the frontend and backend are built and pushed to **ECR** (AWS's container registry), explicitly built for `linux/amd64` (required for EKS, regardless of the architecture of the machine building them).
2. Kubernetes manifests (`/k8s` folder) describe the desired state:
   - `backend-deployment.yml` / `backend-service.yml` — 2 backend replicas, exposed only internally (`ClusterIP`)
   - `frontend-deployment.yml` / `frontend-service.yml` — 2 frontend replicas, exposed publicly (`LoadBalancer`)
3. `kubectl apply -f <file>` tells Kubernetes to make that desired state real.
4. Kubernetes continuously ensures the correct number of replicas are running, restarting any pod that fails.

To deploy a new version of the code: rebuild and push the Docker image, then run:
```bash
kubectl rollout restart deployment <deployment-name>
```
This replaces pods gradually, with zero downtime.

---

## 6. How Security Is Implemented

- **Network isolation:** RDS and Redis security groups allow traffic ONLY from within the VPC (`10.0.0.0/16`) — never from the public internet, not even a specific developer IP.
- **Least privilege IAM:** separate IAM roles exist for the EKS cluster itself, the EKS worker nodes, each scoped to only the permissions AWS documentation specifies as required — no broad `AdministratorAccess` used anywhere in this stack.
- **Public exposure minimized:** only the frontend Service is internet-facing. The backend, database, and cache are reachable exclusively through internal Kubernetes/VPC networking.
- **Automated verification:** a Python security scanner (from the DevOps learning journey) was run against the live account and confirmed no security groups expose SSH to the internet.

---

## 7. How Failures Are Detected / Handled

- **Self-healing:** Kubernetes continuously monitors all 4 pods (2 frontend, 2 backend). If a pod crashes, a replacement is automatically created within seconds — no human intervention required.
- **Load distribution:** 2 replicas of each service mean the app tolerates a single pod failure without downtime — the Load Balancer and Kubernetes Service automatically stop routing to unhealthy pods.
- **Monitoring:** EKS control plane logging (API calls, authentication, scheduling decisions) streams to CloudWatch, providing visibility into cluster-level activity for troubleshooting.

---

## 8. How the System Could Scale

- **Horizontal scaling:** increasing `replicas:` in the Deployment YAMLs (or adding a Horizontal Pod Autoscaler) would add more frontend/backend copies to handle increased traffic.
- **Node scaling:** the EKS node group's `scaling_config` (currently min 1, desired 2, max 2) could be increased to add more underlying compute capacity.
- **Database scaling:** RDS supports Multi-AZ deployment (a live standby copy) and Read Replicas for read-heavy workloads — not implemented here to keep costs minimal for a learning project, but a natural next step.
- **CDN caching:** CloudFront could be added in front of the Load Balancer to cache static frontend assets closer to users worldwide (attempted during the learning journey; blocked by a new-account verification requirement at the time).

---

## 9. Project Structure

```
devops-capstone/
├── backend/
│   ├── app.py              # Flask API (visit/count/health endpoints)
│   ├── Dockerfile
│   └── requirements.txt
├── frontend/
│   ├── index.html          # Static page + JS calling the API
│   ├── nginx.conf          # Reverse proxy config (/api/ → backend-service)
│   └── Dockerfile
├── terraform/
│   ├── provider.tf
│   ├── vpc.tf
│   ├── eks.tf
│   ├── eks-nodes.tf
│   ├── rds.tf
│   └── redis.tf
└── k8s/
    ├── backend-deployment.yml
    ├── backend-service.yml
    ├── frontend-deployment.yml
    └── frontend-service.yml
```

---

## 10. Skills Demonstrated

Linux · Bash · Git · Networking/SSH · Docker · AWS (EC2, VPC, ECR, EKS, RDS, ElastiCache, Route53) · Terraform (Infrastructure as Code) · Kubernetes (Deployments, Services, self-healing) · CI/CD concepts · IAM least-privilege security · Python automation (boto3) · Monitoring (CloudWatch) · Real-world debugging (architecture mismatches, free-tier restrictions, Terraform state gaps, IP rotation, reverse proxy configuration)

---

*Built as the capstone project of a 22-day, from-scratch DevOps learning journey.*
