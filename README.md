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
6. `kind create cluster --name demo --config kind-istio.yaml`
7. `terraform init`
8. `terraform apply --auto-approve`

# Simple Server
Deploy simple server:
1. `cd charts/simple-server`
2. `helm upgrade --install simple-server . -f values.yaml -n test``

# Canary Upgrade
The terraform installed flagger and a loadtester. Inside `charts/simple-server/values.yaml` edit the image to `latest` and run `helm upgrade` to witness a canary upgrade. You can view progress through kubernetes events or `watch kubectl get canaries --all-namespaces`.

# Gateway
You can now reach the gateway on http://localhost:80 

# Contributing
Please do, just open a PR.
