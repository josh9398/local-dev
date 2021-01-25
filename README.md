# Local k8s
Run production like k8s cluster locally using kind. Installs Istio with working ingressgateway, prometheus monitoring and flagger.

# Requierments

- terraform
- docker
- docker-compose
- kubectl
- helm
- kind

# Getting started
The terraform assumes there is a local helm repo as a source for istio charts (couldn't find a public one).

1. `docker-compose up -d`
2. `helm repo add local http://localhost:8080`
3. `helm plugin install https://github.com/chartmuseum/helm-push.git`
4. `git clone git@github.com:istio/istio.git`
5. Within the Istio repo run `helm push . local` inside each chart under `manifests/charts`
6. `kind create cluster --name demo --config kind.yaml`
7. `terraform init`
8. `terraform apply --auto-approve`

# Gateway
You can now reach the gateway on http://localhost:80 

# Contributing
Please do, just open a PR.