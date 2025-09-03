terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.105.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "mk8s" {
  name     = "mk8s"
  location = "westeurope"
}

data "azurerm_kubernetes_service_versions" "current" {
  location = azurerm_resource_group.mk8s.location
}

resource "azurerm_kubernetes_cluster" "mk8s-cluster" {
  name                = "mk8s-cluster"
  location            = azurerm_resource_group.mk8s.location
  resource_group_name = azurerm_resource_group.mk8s.name
  dns_prefix          = "mk8s-cluster"
  kubernetes_version = data.azurerm_kubernetes_service_versions.current.versions[length(data.azurerm_kubernetes_service_versions.current.versions)-1]  # Use current stable version

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_B2s"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "kubenet"
    network_policy = "calico"
  }

  tags = {
    environment = "Terraform"
  }
}

# Data source to get cluster credentials after creation
data "azurerm_kubernetes_cluster" "mk8s-cluster" {
  name                = azurerm_kubernetes_cluster.mk8s-cluster.name
  resource_group_name = azurerm_resource_group.mk8s.name

  depends_on = [azurerm_kubernetes_cluster.mk8s-cluster]
}

# Kubernetes provider using data source
provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.mk8s-cluster.kube_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.mk8s-cluster.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.mk8s-cluster.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.mk8s-cluster.kube_config.0.cluster_ca_certificate)
}

# Helm provider using data source
provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.mk8s-cluster.kube_config.0.host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.mk8s-cluster.kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.mk8s-cluster.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.mk8s-cluster.kube_config.0.cluster_ca_certificate)
  }
}

resource "kubernetes_namespace" "monitoring2" {
  metadata {
    name = "monitoring2"
  }

  depends_on = [data.azurerm_kubernetes_cluster.mk8s-cluster]
}



resource "helm_release" "prometheus" {
  name       = "prometheus"
  namespace  = kubernetes_namespace.monitoring2.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = "25.8.0"

  set {
    name  = "server.persistentVolume.storageClass"
    value = "default"
  }

  depends_on = [kubernetes_namespace.monitoring2]
}

resource "helm_release" "grafana" {
  name       = "grafana"
  namespace  = kubernetes_namespace.monitoring2.metadata[0].name
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "7.0.17"

  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "persistence.storageClassName"
    value = "default"
  }

  set {
    name  = "adminPassword"
    value = "admin1234"
  }

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "service.port"
    value = "80"
  }

  set {
    name  = "service.targetPort"
    value = "3000"
  }

  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/azure-dns-label-name"
    value = "grafana-${replace(azurerm_kubernetes_cluster.mk8s-cluster.name, "_", "-")}"
  }

  values = [<<EOT
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-server.${kubernetes_namespace.monitoring2.metadata[0].name}.svc.cluster.local
      access: proxy
      isDefault: true
EOT
  ]

  depends_on = [helm_release.prometheus]
}

resource "kubernetes_deployment" "emat" {
  
  metadata {
    name      = "emat"
    namespace = kubernetes_namespace.monitoring2.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "emat" }
    }

    template {
      metadata {
        labels = { app = "emat" }
        annotations = {
            "prometheus.io/scrape"       = "true"
            "prometheus.io/port"         = "8080"
            "prometheus.io/path"         = "/metrics"
            }
      }

      spec {
        container {
          name  = "emat"
          image = "haxor44/python-app:latest" 
          port {
            container_port = 5000
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "emat" {
    metadata {
        name      = "emat"
        namespace = kubernetes_namespace.monitoring2.metadata[0].name
    }
    
    spec {
        selector = { 
            app = "emat" 
        }

        port {
        name        = "web"
        port        = 80
        target_port = 5000
        }

        port {
          name = "metrics"
          port = 8080
          target_port = 8080
        }
        type = "ClusterIP"
    }
    
    depends_on = [kubernetes_deployment.emat]
}


output "grafana_public_url" {
  value = "http://${helm_release.grafana.name}-${replace(azurerm_kubernetes_cluster.mk8s-cluster.name, "_", "-")}.${azurerm_resource_group.mk8s.location}.cloudapp.azure.com"
}

output "grafana_access_command" {
  value = "kubectl port-forward svc/${helm_release.grafana.name} -n ${kubernetes_namespace.monitoring2.metadata[0].name} 3000:80"
}