<!-- markdownlint-configure-file {
  "MD033": false,
  "MD041": false
} -->

# Run Manual

Create mongodb-prerequisites.yaml

```bash
kubectl apply -f mongodb-prerequisites.yaml
```

Install mongodb helm chart

```bash
helm install mongodb \
  -f values-dev.yaml \
  --set auth.rootUser="$(kubectl get secrets mongodb-secrets -o jsonpath='{.data.DB_ROOT_USER}' | base64 -d)" \
  --set auth.rootPassword="$(kubectl get secrets mongodb-secrets -o jsonpath='{.data.DB_ROOT_PASSWORD}' | base64 -d)" \
  --set auth.username="$(kubectl get secrets mongodb-secrets -o jsonpath='{.data.DB_USER}' | base64 -d)" \
  --set auth.password="$(kubectl get secrets mongodb-secrets -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)" \
  --set auth.databases[0]="$(kubectl get cm mongodb-configs -o jsonpath='{.data.DB_NAME}')" \
  bitnami/mongodb
```
