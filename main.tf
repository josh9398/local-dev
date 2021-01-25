terraform {
  required_version = ">= 0.14"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    helm = {
      version = "~> 2.0.1"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config" // path to kubeconfig
}

provider "kubernetes-alpha" {
  config_path = "~/.kube/config" // path to kubeconfig
}

provider "kubectl" {
  config_path = "~/.kube/config" // path to kubeconfig
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config" // path to kubeconfig
  }
}



# ----------------------------------------------------------------------------------------------------------------------
# istio 
# ----------------------------------------------------------------------------------------------------------------------
resource "kubernetes_namespace" "istio-system" {
  metadata {
    name = "istio-system"
  }
}

locals {
  helmChartValuesIstio = {
    global = {
      jwtPolicy = "first-party-jwt"
    }
    gateways = {
      istio-ingressgateway = {
        type = "NodePort"
        nodeSelector = {
          ingress-ready = "true"
        }
        ports = [
          {
            port       = 15021
            targetPort = 15021
            nodePort   = 30002
            name       = "status-port"
            protocol   = "TCP"
          },
          {
            port       = 80
            targetPort = 8080
            nodePort   = 30000
            name       = "http2"
            protocol   = "TCP"
          },
          {
            port       = 443
            targetPort = 8443
            nodePort   = 30001
            name       = "https"
            protocol   = "TCP"
          }
        ]
      }
    }
  }
}

resource "helm_release" "istio-base" {
  name       = "istio-base"
  repository = "http://localhost:8080"
  chart      = "base"
  namespace  = kubernetes_namespace.istio-system.id

  values = [
    yamlencode(local.helmChartValuesIstio)
  ]
}

resource "helm_release" "istio-discovery" {
  name       = "istio-discovery"
  repository = "http://localhost:8080"
  chart      = "istio-discovery"
  namespace  = kubernetes_namespace.istio-system.id

  values = [
    yamlencode(local.helmChartValuesIstio)
  ]

  depends_on = [helm_release.istio-base]
}

resource "helm_release" "istio-ingress" {
  name       = "istio-ingress"
  repository = "http://localhost:8080"
  chart      = "istio-ingress"
  namespace  = kubernetes_namespace.istio-system.id

  values = [
    yamlencode(local.helmChartValuesIstio)
  ]

  depends_on = [helm_release.istio-base]
}

# ----------------------------------------------------------------------------------------------------------------------
# prometheus
# ----------------------------------------------------------------------------------------------------------------------
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

locals {
  helmChartValuesPrometheus = {
    alertmanager = {
      enabled = false
    }
    pushgateway = {
      enabled = false
    }
    server = {
      persistentVolume = {
        enabled = false
      }
    }
    extraScrapeConfigs = <<-EOT
    # Scrape config for envoy stats
    - job_name: 'envoy-stats'
      metrics_path: /stats/prometheus
      scrape_interval: 15s
      scrape_timeout: 10s
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [meta_kubernetes_pod_container_port_name]
        action: keep
        regex: '.*-envoy-prom'
      - source_labels: [__address, meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:15090
        target_label: __address
      - action: labeldrop
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: pod_name
    EOT
  }
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = kubernetes_namespace.monitoring.id

  values = [
    yamlencode(local.helmChartValuesPrometheus)
  ]

  depends_on = [
    helm_release.istio-base,
    helm_release.istio-discovery
  ]
}

# ----------------------------------------------------------------------------------------------------------------------
# flagger
# ----------------------------------------------------------------------------------------------------------------------
locals {
  helmChartValuesFlagger = {
    crd = {
      create = false
    }
    meshProvider  = "istio"
    metricsServer = "http://prometheus-server.${kubernetes_namespace.monitoring.id}:80"
  }
}

data "http" "flagger-crds" {
  url = "https://raw.githubusercontent.com/fluxcd/flagger/main/artifacts/flagger/crd.yaml"
}

resource "kubectl_manifest" "flagger-crds" {
  yaml_body = data.http.flagger-crds.body

  depends_on = [
    helm_release.istio-base,
    helm_release.istio-discovery
  ]
}

resource "helm_release" "flagger" {
  name       = "flagger"
  repository = "https://flagger.app"
  chart      = "flagger"
  namespace  = kubernetes_namespace.istio-system.id

  values = [
    yamlencode(local.helmChartValuesFlagger)
  ]

  depends_on = [
    helm_release.istio-base,
    helm_release.istio-discovery,
    kubectl_manifest.flagger-crds
  ]
}

# ----------------------------------------------------------------------------------------------------------------------
# demo
# ----------------------------------------------------------------------------------------------------------------------
resource "kubernetes_namespace" "test" {
  metadata {
    name = "test"

    labels = {
      istio-injection = "enabled"
    }
  }
}