#!/bin/bash

# exit on errors
set -e

echo "[INFO] adding stable helm repo"
helm repo add stable https://charts.helm.sh/stable
echo "[INFO] adding prometheus-community helm repo"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
echo "[INFO] updating helm repos"
helm repo update

prometheus_namespace=monitoring

echo "[INFO] installing prometheus.."
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace "${prometheus_namespace}" \
  --create-namespace \
  --kubeconfig /etc/rancher/k3s/k3s.yaml

grafana_exposed_svc_name=prometheus-grafana-external
grafana_target_nodeport=30000
echo "[INFO] exposing prometheus-grafana externally"
kubectl expose deployment prometheus-grafana \
  --port 80 \
  --target-port 3000 \
  --type NodePort \
  --name "${grafana_exposed_svc_name}" \
  --namespace "${prometheus_namespace}"

echo "[INFO] set ${grafana_exposed_svc_name} port to ${grafana_target_nodeport}"
kubectl patch service "${grafana_exposed_svc_name}" \
  --namespace="${prometheus_namespace}" \
  --type='json' \
  --patch='[{"op": "replace", "path": "/spec/ports/0/nodePort", "value":'"${grafana_target_nodeport}"'}]'

echo "[INFO] waiting for prometheus-grafana pods to be up.."
kubectl wait --namespace "${prometheus_namespace}" \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=prometheus,app.kubernetes.io/name=grafana \
  --timeout=220s 2>&1 || echo "[WARNING] prometheus-grafana pods didn't run in timeout grace period. this could be due to limited network bandwidth or something went wrong. if installation process failed rerun again may solve the problem"

echo "[INFO] congratulations! you can now access grafana at http://localhost:${grafana_target_nodeport} (Press CTRL + link to open)"
echo "[INFO] first time login creds:"
echo "  - username: admin"
echo "  - password: prom-operator"

prometheus_exposed_svc_name=prometheus-external
prometheus_target_nodeport=30001
kubectl expose "$(kubectl get -n "${prometheus_namespace}" pods -l app.kubernetes.io/name=prometheus,prometheus=prometheus-kube-prometheus-prometheus -o name)" \
  --port 9090 \
  --type NodePort \
  --name "${prometheus_exposed_svc_name}" \
  --namespace "${prometheus_namespace}"

echo "[INFO] set ${prometheus_exposed_svc_name} port to ${prometheus_target_nodeport}"
kubectl patch service "${prometheus_exposed_svc_name}" \
  --namespace="${prometheus_namespace}" \
  --type='json' \
  --patch='[{"op": "replace", "path": "/spec/ports/0/nodePort", "value":'"${prometheus_target_nodeport}"'}]'

echo "[INFO] waiting for kube-prometheus-prometheus pods to be up.."
kubectl wait --namespace "${prometheus_namespace}" \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=prometheus,prometheus=prometheus-kube-prometheus-prometheus \
  --timeout=220s 2>&1 || echo "[WARNING] kube-prometheus-prometheus pods didn't run in timeout grace period. this could be due to limited network bandwidth or something went wrong. if installation process failed rerun again may solve the problem"

echo "[INFO] congratulations! you can now access prometheus at http://localhost:${prometheus_target_nodeport} (Press CTRL + link to open)"
