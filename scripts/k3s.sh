#!/bin/bash

# exit on errors
set -e

echo "[INFO] installing k3s v1.25.7+k3s1"
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.25.7+k3s1 sh -
# ! I am facing errors with this version on installing NGINX ingress controller
# ! MountVolume.SetUp failed for volume "webhook-cert" : secret "ingress-nginx-admission" not found
# curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.19.5+k3s1 sh -

if [[ ! -d "/home/vagrant/.kube" ]]; then
    echo "[INFO] /home/vagrant/.kube/ doesn't exist. creating.."
    install -d -m 0755 -o vagrant -g vagrant /home/vagrant/.kube
fi

echo "[INFO] installing kubeconfig to vagrant user"
install -C -m 600 -o vagrant -g vagrant /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config

echo -e "\n# export kubeconfig file location\nexport KUBECONFIG=~/.kube/config" >>/home/vagrant/.bashrc

echo "[INFO] wait 30s till control plane components are created"
sleep 30

echo "[INFO] waiting for metrics-server pods to be up.."
kubectl wait --namespace kube-system \
    --for=condition=ready pod \
    --selector=k8s-app=metrics-server \
    --timeout=220s 2>&1 || echo "[WARNING] metrics-server pods didn't run in timeout grace period. this could be due to limited network bandwidth or something went wrong. if installation process failed rerun again may solve the problem"

echo "[INFO] downloading and installing helm.."
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

echo "[INFO] installing Nginx ingress-controller.."
# ! requires kubernetes +v1.20.x
helm upgrade --install ingress-nginx ingress-nginx \
    --repo https://kubernetes.github.io/ingress-nginx \
    --namespace ingress-nginx --create-namespace \
    --kubeconfig /etc/rancher/k3s/k3s.yaml

# Helm is more efficient
# kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.0.3/deploy/static/provider/cloud/deploy.yaml

echo "[INFO] waiting for nginx ingress-controller pods to be up.."
kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=360s 2>&1 || echo "[WARNING] nginx ingress-controller pods didn't run in timeout grace period. this could be due to limited network bandwidth or something went wrong. if installation process failed rerun again may solve the problem"

echo "[INFO] adding jetstack helm repo"
helm repo add jetstack https://charts.jetstack.io
echo "[INFO] updating helm repos"
helm repo update

# install cert-manager for jaeger-operator v1.30.0+ installation
echo "[INFO] installing cert-manager"
helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --version v1.9.0 \
    --set startupapicheck.timeout=5m \
    --set installCRDs=true \
    --set webhook.hostNetwork=true \
    --set webhook.securePort=10260 \
    --kubeconfig /etc/rancher/k3s/k3s.yaml
