# AKS Monitoring with Terraform, Grafana, and Prometheus

This project demonstrates infrastructure-as-code approach to deploy Azure Kubernetes Service (AKS) with monitoring capabilities using Terraform, Prometheus and Grafana, as well as sending slack notifications for successful commits.

<img width="1531" height="689" alt="Screenshot from 2025-09-05 22-55-03" src="https://github.com/user-attachments/assets/27e2cdf6-f44a-48dc-8bce-3dc6dacb57b2" />



## 🏗️ Architecture

```
Terraform → Azure Resources (AKS, ACR) → Helm Charts → Application + Monitoring Stack
```

## 📋 Prerequisites

- Azure CLI
- Terraform (≥ 1.0)
- kubectl
- Helm (v3.x)

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone <repository-url>
cd aks-monitoring-terraform
```

### 2. Initialize Terraform
```bash
terraform init
```

### 3. Review and Customize Configuration
Edit `terraform.tfvars` to match your requirements:
```hcl
resource_group_name = "my-monitoring-rg"
cluster_name        = "my-aks-cluster"
location            = "eastus"
node_count          = 3
```

### 4. Deploy Infrastructure
```bash
terraform plan
terraform apply
```

### 5. Configure kubectl Context
```bash
az aks get-credentials --resource-group $(terraform output -raw resource_group_name) --name $(terraform output -raw cluster_name)
```

### 6. Deploy Monitoring Stack
```bash
# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install monitoring stack
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

### 7. Deploy Sample Application
```bash
kubectl apply -f kubernetes/sample-app/
```

### 8. Access Grafana Dashboard
```bash
# Get Grafana admin password
kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode

# Port-forward Grafana service
kubectl port-forward --namespace monitoring service/prometheus-grafana 3000:80
```

Access Grafana at `http://localhost:3000` with username `admin` and the password obtained above.

<img width="1533" height="824" alt="Screenshot from 2025-07-29 01-47-55" src="https://github.com/user-attachments/assets/8c775602-da4c-43f1-a5f7-2aca1dffed2a" />

<img width="1533" height="824" alt="Screenshot from 2025-07-29 01-47-14" src="https://github.com/user-attachments/assets/39d0ecdd-eda8-4c00-a2ac-beae083f1ada" />


<img width="1533" height="824" alt="Screenshot from 2025-07-29 01-46-23" src="https://github.com/user-attachments/assets/77125860-b796-411c-bf99-351d2739cf12" />


## 📁 Project Structure

```
.
├── main.tf                 # Main Terraform configuration
├── variables.tf           # Terraform variables
├── outputs.tf            # Terraform outputs
├── terraform.tfvars      # Terraform variables values
├── kubernetes/
│   ├── sample-app/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── hpa.yaml
│   └── monitoring/
│       └── values.yaml   # Helm values for monitoring stack
└── scripts/
    └── deploy.sh         # Deployment script
```

## 🔧 Terraform Configuration

The Terraform configuration provisions:

### Azure Resources
- Resource Group
- Azure Kubernetes Service (AKS) cluster
- Azure Container Registry (ACR)
- Network resources (VNet, Subnets)
- Managed Identities for cluster permissions

### Kubernetes Resources
- Namespaces for applications and monitoring
- Storage classes for persistent volumes
- Network policies

## 📊 Monitoring Features

### Pre-configured Dashboards
- Kubernetes cluster metrics
- Node resource utilization
- Pod performance and health
- Application-specific metrics

### Alerting
- Pre-configured alert rules for:
  - Resource usage thresholds
  - Pod restart counts
  - Node health status
  - Application error rates

## 🔄 CI/CD Integration

The Terraform configuration can be integrated with CI/CD pipelines:

### GitHub Actions Example
<img width="1531" height="689" alt="Screenshot from 2025-09-05 23-04-56" src="https://github.com/user-attachments/assets/98666f56-dff1-45d2-a19d-bdad0ad0acb6" />

```yaml
name: Deploy to AKS
on:
  push:
    branches: [ main ]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: hashicorp/setup-terraform@v2
    - run: terraform init
    - run: terraform validate
    - run: terraform apply -auto-approve
      env:
        ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
        ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}
        ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
        ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}
```

## 🛠️ Management

### Scaling the Cluster
```bash
terraform apply -var="node_count=5"
```

### Upgrading Kubernetes Version
```bash
terraform apply -var="kubernetes_version=1.27.3"
```

### Destroying Resources
```bash
terraform destroy
```

## 📈 Customization

### Adding New Applications
1. Create Kubernetes manifests in `kubernetes/` directory
2. Add Terraform configuration for any required Azure resources
3. Update monitoring configuration if needed

### Custom Metrics
1. Instrument application with Prometheus client library
2. Add custom dashboards to Grafana
3. Configure additional scrape targets in Prometheus

## 🔍 Troubleshooting

### Common Issues

1. **Terraform Authentication**
   ```bash
   az login
   az account set --subscription="SUBSCRIPTION_ID"
   ```

2. **Kubernetes Resource Issues**
   ```bash
   kubectl get events --sort-by='.lastTimestamp'
   kubectl describe pod <pod-name>
   ```

3. **Monitoring Stack Issues**
   ```bash
   kubectl get pods -n monitoring
   kubectl logs -n monitoring <prometheus-pod>
   ```

### Logging
```bash
# View Terraform logs
export TF_LOG=DEBUG

# View application logs
kubectl logs -l app=sample-app
```

## 📝 License

This project is licensed under the MIT License.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

