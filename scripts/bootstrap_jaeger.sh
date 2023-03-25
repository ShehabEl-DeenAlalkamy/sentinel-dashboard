#!/bin/bash

# exit on errors
set -e

# ? the reason for this is that the graph functionality seems to be buggy on v1.39.0 and we wanna make use of the latest features
# TODO: use version v1.42.0 (latest)
# ! this is not a stable version and doesn't work properly
# ! jaeger-operator can't create jaeger instances on any other namespaces other than it's namespace
# export jaeger_version=v1.28.0
# ! jaeger supports OTLP starting v1.35.1
export jaeger_version=v1.34.1
jaeger_namespace=observability
prometheus_namespace=monitoring

echo "[INFO] creating ${jaeger_namespace} namespace"
kubectl create namespace "${jaeger_namespace}"
echo "[INFO] installing jaeger.."
kubectl create -n "${jaeger_namespace}" -f https://github.com/jaegertracing/jaeger-operator/releases/download/"${jaeger_version}"/jaeger-operator.yaml

# ! used only with jaeger-operator v1.28.0
# Please use the last stable version
# jaegertracing.io_jaegers_crd.yaml
# kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/"${jaeger_version}"/deploy/crds/jaegertracing.io_jaegers_crd.yaml
# # service_account.yaml
# kubectl create -n "${jaeger_namespace}" -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/"${jaeger_version}"/deploy/service_account.yaml
# # role.yaml
# kubectl create -n "${jaeger_namespace}" -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/"${jaeger_version}"/deploy/role.yaml
# # role_binding.yaml
# kubectl create -n "${jaeger_namespace}" -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/"${jaeger_version}"/deploy/role_binding.yaml
# # operator.yaml
# kubectl create -n "${jaeger_namespace}" -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/"${jaeger_version}"/deploy/operator.yaml

# echo "[INFO] enable the cluster-wide permissions for jaeger operator"
# # cluster_role.yaml
# kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/"${jaeger_version}"/deploy/cluster_role.yaml
# # cluster_role_binding.yaml
# kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/"${jaeger_version}"/deploy/cluster_role_binding.yaml

echo "[INFO] expose jaeger-operator"
cat <<EOF | kubectl apply -n "${jaeger_namespace}" -f -
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/name: jaeger-operator
    name: jaeger-operator
  name: jaeger-operator
spec:
  ports:
  - name: http
    port: 8383
    protocol: TCP
    targetPort: 8383
  selector:
    app.kubernetes.io/name: jaeger-operator
    name: jaeger-operator
  type: ClusterIP
EOF

echo "[INFO] waiting for jaeger operator pods to be up.."
kubectl wait --namespace "${jaeger_namespace}" \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=jaeger-operator,name=jaeger-operator \
  --timeout=220s 2>&1 || echo "[WARNING] jaeger operator pods didn't run in timeout grace period. this could be due to limited network bandwidth or something went wrong. if installation process failed rerun again may solve the problem"

echo "[INFO] expose jaeger-operator metrics for prometheus to scrape"
cat <<EOF | kubectl apply -n "${prometheus_namespace}" -f -
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: jaeger-operator
  labels:
    release: prometheus
spec:
  namespaceSelector:
    matchNames:
      - ${jaeger_namespace}
  selector:
    matchLabels:
      name: jaeger-operator
      app.kubernetes.io/name: jaeger-operator
  endpoints:
    - port: http
      interval: 5s
      path: /metrics
EOF

echo "[INFO] deploying hotrod application for testing.."
cat <<EOF | kubectl apply -f -
---
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger
---
apiVersion: v1
kind: Service
metadata:
  name: hotrod
  labels:
    app: hotrod
spec:
  ports:
    - port: 8080
  selector:
    app: hotrod
    tier: frontend
  type: LoadBalancer
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hotrod
  labels:
    app: hotrod
spec:
  selector:
    matchLabels:
      app: hotrod
      tier: frontend
  template:
    metadata:
      labels:
        app: hotrod
        tier: frontend
    spec:
      containers:
        - image: jaegertracing/example-hotrod:latest
          name: hotrod
          env:
            - name: OTEL_EXPORTER_JAEGER_AGENT_HOST
              value: jaeger-agent
            - name: OTEL_EXPORTER_JAEGER_AGENT_PORT
              value: "6831"
            - name: OTEL_EXPORTER_JAEGER_ENDPOINT
              value: http://jaeger-collector:14268/api/traces
          ports:
            - containerPort: 8080
              name: hotrod
EOF

hotrod_exposed_svc_name=hotrod-external
hotrod_target_nodeport=30003
echo "[INFO] exposing hotrod externally"
kubectl expose deployment hotrod \
  --port 8080 \
  --type NodePort \
  --name "${hotrod_exposed_svc_name}"

echo "[INFO] set ${hotrod_exposed_svc_name} port to ${hotrod_target_nodeport}"
kubectl patch service "${hotrod_exposed_svc_name}" \
  --type='json' \
  --patch='[{"op": "replace", "path": "/spec/ports/0/nodePort", "value":'"${hotrod_target_nodeport}"'}]' #\

echo "[INFO] wait 12s till jaeger instance components are created"
sleep 12

echo "[INFO] waiting for jaeger instance pods to be up.."
kubectl wait \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=all-in-one,app.kubernetes.io/instance=jaeger,app.kubernetes.io/managed-by=jaeger-operator \
  --timeout=220s 2>&1 || echo "[WARNING] jaeger instance pods didn't run in timeout grace period. this could be due to limited network bandwidth or something went wrong. if installation process failed rerun again may solve the problem"

sleep 15s

echo "[INFO] creating jaeger all-in-one configurations"
cat <<EOF | kubectl apply -n "${prometheus_namespace}" -f -
---
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: jaeger-all-in-one
  labels:
    release: prometheus
spec:
  podMetricsEndpoints:
  - interval: 5s
    targetPort: 14269
  namespaceSelector:
    matchNames:
      - default
  selector:
    matchLabels:
      app: jaeger
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-grafana-jaeger-all-in-one-conifguration
  labels:
    grafana_datasource: "1"
    grafana_dashboard: "1"
data:
  datasource.yaml: |-
    apiVersion: 1
    datasources:
      - name: Jaeger
        type: jaeger
        url: http://jaeger-query.default:16686
        access: proxy
        isDefault: false

  jaeger-all-in-one-overview.json: |-
      {
        "annotations": {
          "list": [
            {
              "builtIn": 1,
              "datasource": {
                "type": "datasource",
                "uid": "grafana"
              },
              "enable": true,
              "hide": true,
              "iconColor": "rgba(0, 211, 255, 1)",
              "name": "Annotations & Alerts",
              "target": {
                "limit": 100,
                "matchAny": false,
                "tags": [],
                "type": "dashboard"
              },
              "type": "dashboard"
            }
          ]
        },
        "description": "Dashboard for monitoring jaeger-all-in-one running in a k8s environment. Relying on the official mirror, four core monitoring indicators of Jaeger Collector are added.",
        "editable": true,
        "fiscalYearStartMonth": 0,
        "gnetId": 12535,
        "graphTooltip": 0,
        "id": 29,
        "links": [],
        "liveNow": false,
        "panels": [
          {
            "collapsed": false,
            "datasource": {
              "type": "prometheus",
              "uid": "prometheus"
            },
            "gridPos": {
              "h": 1,
              "w": 24,
              "x": 0,
              "y": 0
            },
            "id": 32,
            "panels": [],
            "targets": [
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "refId": "A"
              }
            ],
            "title": "Jaeger Collector",
            "type": "row"
          },
          {
            "datasource": {
              "type": "prometheus",
              "uid": "prometheus"
            },
            "fieldConfig": {
              "defaults": {
                "color": {
                  "mode": "palette-classic"
                },
                "custom": {
                  "axisCenteredZero": false,
                  "axisColorMode": "text",
                  "axisLabel": "",
                  "axisPlacement": "auto",
                  "barAlignment": 0,
                  "drawStyle": "line",
                  "fillOpacity": 10,
                  "gradientMode": "none",
                  "hideFrom": {
                    "legend": false,
                    "tooltip": false,
                    "viz": false
                  },
                  "lineInterpolation": "linear",
                  "lineWidth": 1,
                  "pointSize": 5,
                  "scaleDistribution": {
                    "type": "linear"
                  },
                  "showPoints": "never",
                  "spanNulls": false,
                  "stacking": {
                    "group": "A",
                    "mode": "none"
                  },
                  "thresholdsStyle": {
                    "mode": "off"
                  }
                },
                "links": [],
                "mappings": [],
                "thresholds": {
                  "mode": "absolute",
                  "steps": [
                    {
                      "color": "green",
                      "value": null
                    },
                    {
                      "color": "red",
                      "value": 80
                    }
                  ]
                },
                "unit": "short"
              },
              "overrides": []
            },
            "gridPos": {
              "h": 7,
              "w": 8,
              "x": 0,
              "y": 1
            },
            "id": 34,
            "links": [],
            "options": {
              "legend": {
                "calcs": [],
                "displayMode": "list",
                "placement": "bottom",
                "showLegend": true
              },
              "tooltip": {
                "mode": "multi",
                "sort": "none"
              }
            },
            "pluginVersion": "9.3.8",
            "targets": [
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "expr": "sum(rate(jaeger_spans_received_total[1m]))",
                "format": "time_series",
                "hide": false,
                "interval": "",
                "intervalFactor": 1,
                "legendFormat": "",
                "refId": "A"
              }
            ],
            "title": "Spans Received/sec",
            "type": "timeseries"
          },
          {
            "datasource": {
              "type": "prometheus",
              "uid": "prometheus"
            },
            "fieldConfig": {
              "defaults": {
                "color": {
                  "mode": "palette-classic"
                },
                "custom": {
                  "axisCenteredZero": false,
                  "axisColorMode": "text",
                  "axisLabel": "",
                  "axisPlacement": "auto",
                  "barAlignment": 0,
                  "drawStyle": "line",
                  "fillOpacity": 10,
                  "gradientMode": "none",
                  "hideFrom": {
                    "legend": false,
                    "tooltip": false,
                    "viz": false
                  },
                  "lineInterpolation": "linear",
                  "lineWidth": 1,
                  "pointSize": 5,
                  "scaleDistribution": {
                    "type": "linear"
                  },
                  "showPoints": "never",
                  "spanNulls": false,
                  "stacking": {
                    "group": "A",
                    "mode": "none"
                  },
                  "thresholdsStyle": {
                    "mode": "off"
                  }
                },
                "links": [],
                "mappings": [],
                "thresholds": {
                  "mode": "absolute",
                  "steps": [
                    {
                      "color": "green",
                      "value": null
                    },
                    {
                      "color": "red",
                      "value": 80
                    }
                  ]
                },
                "unit": "short"
              },
              "overrides": []
            },
            "gridPos": {
              "h": 7,
              "w": 8,
              "x": 8,
              "y": 1
            },
            "id": 36,
            "links": [],
            "options": {
              "legend": {
                "calcs": [],
                "displayMode": "list",
                "placement": "bottom",
                "showLegend": true
              },
              "tooltip": {
                "mode": "multi",
                "sort": "none"
              }
            },
            "pluginVersion": "9.3.8",
            "targets": [
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "expr": "jaeger_in_queue_latency_sum / jaeger_in_queue_latency_count",
                "format": "time_series",
                "hide": false,
                "interval": "",
                "intervalFactor": 1,
                "legendFormat": "",
                "refId": "A"
              }
            ],
            "title": "Average in-queue latency (sec)",
            "type": "timeseries"
          },
          {
            "datasource": {
              "type": "prometheus",
              "uid": "prometheus"
            },
            "fieldConfig": {
              "defaults": {
                "color": {
                  "mode": "palette-classic"
                },
                "custom": {
                  "axisCenteredZero": false,
                  "axisColorMode": "text",
                  "axisLabel": "",
                  "axisPlacement": "auto",
                  "barAlignment": 0,
                  "drawStyle": "line",
                  "fillOpacity": 10,
                  "gradientMode": "none",
                  "hideFrom": {
                    "legend": false,
                    "tooltip": false,
                    "viz": false
                  },
                  "lineInterpolation": "linear",
                  "lineWidth": 1,
                  "pointSize": 5,
                  "scaleDistribution": {
                    "type": "linear"
                  },
                  "showPoints": "never",
                  "spanNulls": false,
                  "stacking": {
                    "group": "A",
                    "mode": "none"
                  },
                  "thresholdsStyle": {
                    "mode": "off"
                  }
                },
                "links": [],
                "mappings": [],
                "thresholds": {
                  "mode": "absolute",
                  "steps": [
                    {
                      "color": "green",
                      "value": null
                    },
                    {
                      "color": "red",
                      "value": 80
                    }
                  ]
                },
                "unit": "short"
              },
              "overrides": []
            },
            "gridPos": {
              "h": 7,
              "w": 8,
              "x": 16,
              "y": 1
            },
            "id": 42,
            "links": [],
            "options": {
              "legend": {
                "calcs": [],
                "displayMode": "list",
                "placement": "bottom",
                "showLegend": true
              },
              "tooltip": {
                "mode": "multi",
                "sort": "none"
              }
            },
            "pluginVersion": "9.3.8",
            "targets": [
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "expr": "jaeger_batch_size",
                "format": "time_series",
                "interval": "",
                "intervalFactor": 1,
                "legendFormat": "",
                "refId": "A"
              }
            ],
            "title": "Batch Size (spans)",
            "type": "timeseries"
          },
          {
            "datasource": {
              "type": "prometheus",
              "uid": "prometheus"
            },
            "fieldConfig": {
              "defaults": {
                "color": {
                  "mode": "palette-classic"
                },
                "custom": {
                  "axisCenteredZero": false,
                  "axisColorMode": "text",
                  "axisLabel": "",
                  "axisPlacement": "auto",
                  "barAlignment": 0,
                  "drawStyle": "line",
                  "fillOpacity": 10,
                  "gradientMode": "none",
                  "hideFrom": {
                    "legend": false,
                    "tooltip": false,
                    "viz": false
                  },
                  "lineInterpolation": "linear",
                  "lineWidth": 1,
                  "pointSize": 5,
                  "scaleDistribution": {
                    "type": "linear"
                  },
                  "showPoints": "never",
                  "spanNulls": false,
                  "stacking": {
                    "group": "A",
                    "mode": "none"
                  },
                  "thresholdsStyle": {
                    "mode": "off"
                  }
                },
                "links": [],
                "mappings": [],
                "thresholds": {
                  "mode": "absolute",
                  "steps": [
                    {
                      "color": "green",
                      "value": null
                    },
                    {
                      "color": "red",
                      "value": 80
                    }
                  ]
                },
                "unit": "short"
              },
              "overrides": []
            },
            "gridPos": {
              "h": 7,
              "w": 8,
              "x": 0,
              "y": 8
            },
            "id": 38,
            "links": [],
            "options": {
              "legend": {
                "calcs": [],
                "displayMode": "list",
                "placement": "bottom",
                "showLegend": true
              },
              "tooltip": {
                "mode": "multi",
                "sort": "none"
              }
            },
            "pluginVersion": "9.3.8",
            "targets": [
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "expr": "jaeger_queue_length",
                "format": "time_series",
                "hide": false,
                "interval": "",
                "intervalFactor": 1,
                "legendFormat": "",
                "refId": "A"
              }
            ],
            "title": "Queue Length (Spans)",
            "type": "timeseries"
          },
          {
            "datasource": {
              "type": "prometheus",
              "uid": "prometheus"
            },
            "fieldConfig": {
              "defaults": {
                "color": {
                  "mode": "palette-classic"
                },
                "custom": {
                  "axisCenteredZero": false,
                  "axisColorMode": "text",
                  "axisLabel": "",
                  "axisPlacement": "auto",
                  "barAlignment": 0,
                  "drawStyle": "line",
                  "fillOpacity": 10,
                  "gradientMode": "none",
                  "hideFrom": {
                    "legend": false,
                    "tooltip": false,
                    "viz": false
                  },
                  "lineInterpolation": "linear",
                  "lineWidth": 1,
                  "pointSize": 5,
                  "scaleDistribution": {
                    "type": "linear"
                  },
                  "showPoints": "never",
                  "spanNulls": false,
                  "stacking": {
                    "group": "A",
                    "mode": "none"
                  },
                  "thresholdsStyle": {
                    "mode": "off"
                  }
                },
                "links": [],
                "mappings": [],
                "thresholds": {
                  "mode": "absolute",
                  "steps": [
                    {
                      "color": "green",
                      "value": null
                    },
                    {
                      "color": "red",
                      "value": 80
                    }
                  ]
                },
                "unit": "short"
              },
              "overrides": []
            },
            "gridPos": {
              "h": 7,
              "w": 8,
              "x": 8,
              "y": 8
            },
            "id": 40,
            "links": [],
            "options": {
              "legend": {
                "calcs": [],
                "displayMode": "list",
                "placement": "bottom",
                "showLegend": true
              },
              "tooltip": {
                "mode": "multi",
                "sort": "none"
              }
            },
            "pluginVersion": "9.3.8",
            "targets": [
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "expr": "rate(jaeger_spans_dropped_total[5m])",
                "format": "time_series",
                "interval": "",
                "intervalFactor": 1,
                "legendFormat": "",
                "refId": "A"
              }
            ],
            "title": "Spans Dropped/sec",
            "type": "timeseries"
          },
          {
            "datasource": {
              "type": "prometheus",
              "uid": "prometheus"
            },
            "fieldConfig": {
              "defaults": {
                "color": {
                  "mode": "palette-classic"
                },
                "custom": {
                  "axisCenteredZero": false,
                  "axisColorMode": "text",
                  "axisLabel": "",
                  "axisPlacement": "auto",
                  "barAlignment": 0,
                  "drawStyle": "line",
                  "fillOpacity": 10,
                  "gradientMode": "none",
                  "hideFrom": {
                    "legend": false,
                    "tooltip": false,
                    "viz": false
                  },
                  "lineInterpolation": "linear",
                  "lineWidth": 1,
                  "pointSize": 5,
                  "scaleDistribution": {
                    "type": "linear"
                  },
                  "showPoints": "never",
                  "spanNulls": false,
                  "stacking": {
                    "group": "A",
                    "mode": "none"
                  },
                  "thresholdsStyle": {
                    "mode": "off"
                  }
                },
                "links": [],
                "mappings": [],
                "thresholds": {
                  "mode": "absolute",
                  "steps": [
                    {
                      "color": "green",
                      "value": null
                    },
                    {
                      "color": "red",
                      "value": 80
                    }
                  ]
                },
                "unit": "short"
              },
              "overrides": []
            },
            "gridPos": {
              "h": 7,
              "w": 8,
              "x": 16,
              "y": 8
            },
            "id": 44,
            "links": [],
            "options": {
              "legend": {
                "calcs": [],
                "displayMode": "list",
                "placement": "bottom",
                "showLegend": true
              },
              "tooltip": {
                "mode": "multi",
                "sort": "none"
              }
            },
            "pluginVersion": "9.3.8",
            "targets": [
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "expr": "jaeger_save_latency_sum / jaeger_save_latency_count",
                "format": "time_series",
                "interval": "",
                "intervalFactor": 1,
                "legendFormat": "",
                "refId": "A"
              }
            ],
            "title": "Span save latency (sec)",
            "type": "timeseries"
          },
          {
            "datasource": {
              "type": "prometheus",
              "uid": "prometheus"
            },
            "description": "Trace",
            "fieldConfig": {
              "defaults": {
                "color": {
                  "mode": "palette-classic"
                },
                "custom": {
                  "axisCenteredZero": false,
                  "axisColorMode": "text",
                  "axisLabel": "",
                  "axisPlacement": "auto",
                  "barAlignment": 0,
                  "drawStyle": "line",
                  "fillOpacity": 10,
                  "gradientMode": "none",
                  "hideFrom": {
                    "legend": false,
                    "tooltip": false,
                    "viz": false
                  },
                  "lineInterpolation": "linear",
                  "lineWidth": 1,
                  "pointSize": 5,
                  "scaleDistribution": {
                    "type": "linear"
                  },
                  "showPoints": "never",
                  "spanNulls": false,
                  "stacking": {
                    "group": "A",
                    "mode": "none"
                  },
                  "thresholdsStyle": {
                    "mode": "off"
                  }
                },
                "links": [],
                "mappings": [],
                "thresholds": {
                  "mode": "absolute",
                  "steps": [
                    {
                      "color": "green",
                      "value": null
                    },
                    {
                      "color": "red",
                      "value": 80
                    }
                  ]
                },
                "unit": "short"
              },
              "overrides": []
            },
            "gridPos": {
              "h": 8,
              "w": 12,
              "x": 0,
              "y": 15
            },
            "id": 62,
            "options": {
              "legend": {
                "calcs": [],
                "displayMode": "list",
                "placement": "bottom",
                "showLegend": true
              },
              "tooltip": {
                "mode": "multi",
                "sort": "none"
              }
            },
            "pluginVersion": "9.3.8",
            "targets": [
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "editorMode": "code",
                "expr": "jaeger_traces_received_total{svc=\"\$svc\"}",
                "interval": "",
                "legendFormat": "",
                "range": true,
                "refId": "A"
              }
            ],
            "title": "trace_receive_total",
            "type": "timeseries"
          },
          {
            "datasource": {
              "type": "prometheus",
              "uid": "prometheus"
            },
            "description": "保存Save总数",
            "fieldConfig": {
              "defaults": {
                "color": {
                  "mode": "palette-classic"
                },
                "custom": {
                  "axisCenteredZero": false,
                  "axisColorMode": "text",
                  "axisLabel": "",
                  "axisPlacement": "auto",
                  "barAlignment": 0,
                  "drawStyle": "line",
                  "fillOpacity": 10,
                  "gradientMode": "none",
                  "hideFrom": {
                    "legend": false,
                    "tooltip": false,
                    "viz": false
                  },
                  "lineInterpolation": "linear",
                  "lineWidth": 1,
                  "pointSize": 5,
                  "scaleDistribution": {
                    "type": "linear"
                  },
                  "showPoints": "never",
                  "spanNulls": false,
                  "stacking": {
                    "group": "A",
                    "mode": "none"
                  },
                  "thresholdsStyle": {
                    "mode": "off"
                  }
                },
                "links": [],
                "mappings": [],
                "thresholds": {
                  "mode": "absolute",
                  "steps": [
                    {
                      "color": "green",
                      "value": null
                    },
                    {
                      "color": "red",
                      "value": 80
                    }
                  ]
                },
                "unit": "short"
              },
              "overrides": []
            },
            "gridPos": {
              "h": 8,
              "w": 12,
              "x": 12,
              "y": 15
            },
            "id": 66,
            "options": {
              "legend": {
                "calcs": [],
                "displayMode": "list",
                "placement": "bottom",
                "showLegend": true
              },
              "tooltip": {
                "mode": "multi",
                "sort": "none"
              }
            },
            "pluginVersion": "9.3.8",
            "targets": [
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "expr": "jaeger_traces_saved_by_svc_total{svc=\"\$svc\"}",
                "interval": "",
                "legendFormat": "",
                "refId": "A"
              }
            ],
            "title": "traces_saved_by_svc_total",
            "type": "timeseries"
          },
          {
            "datasource": {
              "type": "prometheus",
              "uid": "prometheus"
            },
            "description": "接收Span总数",
            "fieldConfig": {
              "defaults": {
                "color": {
                  "mode": "palette-classic"
                },
                "custom": {
                  "axisCenteredZero": false,
                  "axisColorMode": "text",
                  "axisLabel": "",
                  "axisPlacement": "auto",
                  "barAlignment": 0,
                  "drawStyle": "line",
                  "fillOpacity": 10,
                  "gradientMode": "none",
                  "hideFrom": {
                    "legend": false,
                    "tooltip": false,
                    "viz": false
                  },
                  "lineInterpolation": "linear",
                  "lineWidth": 1,
                  "pointSize": 5,
                  "scaleDistribution": {
                    "type": "linear"
                  },
                  "showPoints": "never",
                  "spanNulls": false,
                  "stacking": {
                    "group": "A",
                    "mode": "none"
                  },
                  "thresholdsStyle": {
                    "mode": "off"
                  }
                },
                "links": [],
                "mappings": [],
                "thresholds": {
                  "mode": "absolute",
                  "steps": [
                    {
                      "color": "green",
                      "value": null
                    },
                    {
                      "color": "red",
                      "value": 80
                    }
                  ]
                },
                "unit": "short"
              },
              "overrides": []
            },
            "gridPos": {
              "h": 8,
              "w": 12,
              "x": 0,
              "y": 23
            },
            "id": 60,
            "options": {
              "legend": {
                "calcs": [],
                "displayMode": "list",
                "placement": "bottom",
                "showLegend": true
              },
              "tooltip": {
                "mode": "multi",
                "sort": "none"
              }
            },
            "pluginVersion": "9.3.8",
            "targets": [
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "expr": "jaeger_spans_received_total{svc=\"\$svc\"}",
                "interval": "",
                "legendFormat": "",
                "refId": "A"
              }
            ],
            "title": "span_received_total",
            "type": "timeseries"
          },
          {
            "datasource": {
              "type": "prometheus",
              "uid": "prometheus"
            },
            "description": "保存Span总数",
            "fieldConfig": {
              "defaults": {
                "color": {
                  "mode": "palette-classic"
                },
                "custom": {
                  "axisCenteredZero": false,
                  "axisColorMode": "text",
                  "axisLabel": "",
                  "axisPlacement": "auto",
                  "barAlignment": 0,
                  "drawStyle": "line",
                  "fillOpacity": 10,
                  "gradientMode": "none",
                  "hideFrom": {
                    "legend": false,
                    "tooltip": false,
                    "viz": false
                  },
                  "lineInterpolation": "linear",
                  "lineWidth": 1,
                  "pointSize": 5,
                  "scaleDistribution": {
                    "type": "linear"
                  },
                  "showPoints": "never",
                  "spanNulls": false,
                  "stacking": {
                    "group": "A",
                    "mode": "none"
                  },
                  "thresholdsStyle": {
                    "mode": "off"
                  }
                },
                "links": [],
                "mappings": [],
                "thresholds": {
                  "mode": "absolute",
                  "steps": [
                    {
                      "color": "green",
                      "value": null
                    },
                    {
                      "color": "red",
                      "value": 80
                    }
                  ]
                },
                "unit": "short"
              },
              "overrides": []
            },
            "gridPos": {
              "h": 8,
              "w": 12,
              "x": 12,
              "y": 23
            },
            "id": 64,
            "options": {
              "legend": {
                "calcs": [],
                "displayMode": "list",
                "placement": "bottom",
                "showLegend": true
              },
              "tooltip": {
                "mode": "multi",
                "sort": "none"
              }
            },
            "pluginVersion": "9.3.8",
            "targets": [
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "expr": "jaeger_spans_saved_by_svc_total{svc=\"\$svc\"}",
                "interval": "",
                "legendFormat": "",
                "refId": "A"
              }
            ],
            "title": "spans_saved_by_svc_total",
            "type": "timeseries"
          },
          {
            "collapsed": true,
            "datasource": {
              "type": "prometheus",
              "uid": "prometheus"
            },
            "gridPos": {
              "h": 1,
              "w": 24,
              "x": 0,
              "y": 31
            },
            "id": 30,
            "panels": [
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "fieldConfig": {
                  "defaults": {
                    "color": {
                      "mode": "palette-classic"
                    },
                    "custom": {
                      "axisCenteredZero": false,
                      "axisColorMode": "text",
                      "axisLabel": "",
                      "axisPlacement": "auto",
                      "barAlignment": 0,
                      "drawStyle": "line",
                      "fillOpacity": 10,
                      "gradientMode": "none",
                      "hideFrom": {
                        "legend": false,
                        "tooltip": false,
                        "viz": false
                      },
                      "lineInterpolation": "linear",
                      "lineWidth": 1,
                      "pointSize": 5,
                      "scaleDistribution": {
                        "type": "linear"
                      },
                      "showPoints": "never",
                      "spanNulls": false,
                      "stacking": {
                        "group": "A",
                        "mode": "none"
                      },
                      "thresholdsStyle": {
                        "mode": "off"
                      }
                    },
                    "links": [],
                    "mappings": [],
                    "thresholds": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "red",
                          "value": 80
                        }
                      ]
                    },
                    "unit": "short"
                  },
                  "overrides": []
                },
                "gridPos": {
                  "h": 6,
                  "w": 8,
                  "x": 0,
                  "y": 2
                },
                "id": 8,
                "links": [],
                "options": {
                  "legend": {
                    "calcs": [],
                    "displayMode": "list",
                    "placement": "bottom",
                    "showLegend": true
                  },
                  "tooltip": {
                    "mode": "multi",
                    "sort": "none"
                  }
                },
                "pluginVersion": "9.3.8",
                "targets": [
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "editorMode": "code",
                    "expr": "sum(rate(jaeger_thrift_udp_server_packets_processed_total[5m])) by (protocol)",
                    "format": "time_series",
                    "interval": "",
                    "intervalFactor": 1,
                    "legendFormat": "",
                    "range": true,
                    "refId": "A"
                  }
                ],
                "title": "jaeger_agent_thrift_udp_server_packets_processed/sec",
                "type": "timeseries"
              },
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "fieldConfig": {
                  "defaults": {
                    "color": {
                      "mode": "palette-classic"
                    },
                    "custom": {
                      "axisCenteredZero": false,
                      "axisColorMode": "text",
                      "axisLabel": "",
                      "axisPlacement": "auto",
                      "barAlignment": 0,
                      "drawStyle": "line",
                      "fillOpacity": 10,
                      "gradientMode": "none",
                      "hideFrom": {
                        "legend": false,
                        "tooltip": false,
                        "viz": false
                      },
                      "lineInterpolation": "linear",
                      "lineWidth": 1,
                      "pointSize": 5,
                      "scaleDistribution": {
                        "type": "linear"
                      },
                      "showPoints": "never",
                      "spanNulls": false,
                      "stacking": {
                        "group": "A",
                        "mode": "none"
                      },
                      "thresholdsStyle": {
                        "mode": "off"
                      }
                    },
                    "links": [],
                    "mappings": [],
                    "thresholds": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "red",
                          "value": 80
                        }
                      ]
                    },
                    "unit": "short"
                  },
                  "overrides": []
                },
                "gridPos": {
                  "h": 6,
                  "w": 8,
                  "x": 8,
                  "y": 2
                },
                "id": 20,
                "links": [],
                "options": {
                  "legend": {
                    "calcs": [],
                    "displayMode": "list",
                    "placement": "bottom",
                    "showLegend": true
                  },
                  "tooltip": {
                    "mode": "multi",
                    "sort": "none"
                  }
                },
                "pluginVersion": "9.3.8",
                "targets": [
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "avg(jaeger_thrift_udp_server_packet_size) by (protocol)",
                    "format": "time_series",
                    "interval": "",
                    "intervalFactor": 1,
                    "legendFormat": "",
                    "refId": "A"
                  }
                ],
                "title": "avg(jaeger_agent_thrift_udp_server_packet_size)",
                "type": "timeseries"
              },
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "fieldConfig": {
                  "defaults": {
                    "color": {
                      "mode": "palette-classic"
                    },
                    "custom": {
                      "axisCenteredZero": false,
                      "axisColorMode": "text",
                      "axisLabel": "",
                      "axisPlacement": "auto",
                      "barAlignment": 0,
                      "drawStyle": "line",
                      "fillOpacity": 10,
                      "gradientMode": "none",
                      "hideFrom": {
                        "legend": false,
                        "tooltip": false,
                        "viz": false
                      },
                      "lineInterpolation": "linear",
                      "lineWidth": 1,
                      "pointSize": 5,
                      "scaleDistribution": {
                        "type": "linear"
                      },
                      "showPoints": "never",
                      "spanNulls": false,
                      "stacking": {
                        "group": "A",
                        "mode": "none"
                      },
                      "thresholdsStyle": {
                        "mode": "off"
                      }
                    },
                    "links": [],
                    "mappings": [],
                    "thresholds": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "red",
                          "value": 80
                        }
                      ]
                    },
                    "unit": "short"
                  },
                  "overrides": []
                },
                "gridPos": {
                  "h": 6,
                  "w": 8,
                  "x": 16,
                  "y": 2
                },
                "id": 24,
                "links": [],
                "options": {
                  "legend": {
                    "calcs": [],
                    "displayMode": "list",
                    "placement": "bottom",
                    "showLegend": true
                  },
                  "tooltip": {
                    "mode": "multi",
                    "sort": "none"
                  }
                },
                "pluginVersion": "9.3.8",
                "targets": [
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "avg(jaeger_thrift_udp_server_queue_size) by (protocol)",
                    "format": "time_series",
                    "interval": "",
                    "intervalFactor": 1,
                    "legendFormat": "",
                    "refId": "A"
                  }
                ],
                "title": "jaeger_agent_thrift_udp_server_queue_size",
                "type": "timeseries"
              },
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "fieldConfig": {
                  "defaults": {
                    "color": {
                      "mode": "palette-classic"
                    },
                    "custom": {
                      "axisCenteredZero": false,
                      "axisColorMode": "text",
                      "axisLabel": "",
                      "axisPlacement": "auto",
                      "barAlignment": 0,
                      "drawStyle": "line",
                      "fillOpacity": 10,
                      "gradientMode": "none",
                      "hideFrom": {
                        "legend": false,
                        "tooltip": false,
                        "viz": false
                      },
                      "lineInterpolation": "linear",
                      "lineWidth": 1,
                      "pointSize": 5,
                      "scaleDistribution": {
                        "type": "linear"
                      },
                      "showPoints": "never",
                      "spanNulls": false,
                      "stacking": {
                        "group": "A",
                        "mode": "none"
                      },
                      "thresholdsStyle": {
                        "mode": "off"
                      }
                    },
                    "links": [],
                    "mappings": [],
                    "thresholds": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "red",
                          "value": 80
                        }
                      ]
                    },
                    "unit": "short"
                  },
                  "overrides": []
                },
                "gridPos": {
                  "h": 6,
                  "w": 8,
                  "x": 0,
                  "y": 8
                },
                "id": 26,
                "links": [],
                "options": {
                  "legend": {
                    "calcs": [],
                    "displayMode": "list",
                    "placement": "bottom",
                    "showLegend": true
                  },
                  "tooltip": {
                    "mode": "multi",
                    "sort": "none"
                  }
                },
                "pluginVersion": "9.3.8",
                "targets": [
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_thrift_udp_server_read_errors_total[5m])) by (protocol)",
                    "format": "time_series",
                    "interval": "",
                    "intervalFactor": 1,
                    "legendFormat": "",
                    "refId": "A"
                  }
                ],
                "title": "jaeger_agent_thrift_udp_server_read_errors/sec",
                "type": "timeseries"
              },
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "fieldConfig": {
                  "defaults": {
                    "color": {
                      "mode": "palette-classic"
                    },
                    "custom": {
                      "axisCenteredZero": false,
                      "axisColorMode": "text",
                      "axisLabel": "",
                      "axisPlacement": "auto",
                      "barAlignment": 0,
                      "drawStyle": "line",
                      "fillOpacity": 10,
                      "gradientMode": "none",
                      "hideFrom": {
                        "legend": false,
                        "tooltip": false,
                        "viz": false
                      },
                      "lineInterpolation": "linear",
                      "lineWidth": 1,
                      "pointSize": 5,
                      "scaleDistribution": {
                        "type": "linear"
                      },
                      "showPoints": "never",
                      "spanNulls": false,
                      "stacking": {
                        "group": "A",
                        "mode": "none"
                      },
                      "thresholdsStyle": {
                        "mode": "off"
                      }
                    },
                    "links": [],
                    "mappings": [],
                    "thresholds": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "red",
                          "value": 80
                        }
                      ]
                    },
                    "unit": "short"
                  },
                  "overrides": []
                },
                "gridPos": {
                  "h": 6,
                  "w": 8,
                  "x": 8,
                  "y": 8
                },
                "id": 22,
                "links": [],
                "options": {
                  "legend": {
                    "calcs": [],
                    "displayMode": "list",
                    "placement": "bottom",
                    "showLegend": true
                  },
                  "tooltip": {
                    "mode": "multi",
                    "sort": "none"
                  }
                },
                "pluginVersion": "9.3.8",
                "targets": [
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_thrift_udp_server_packets_dropped_total[5m])) by (protocol)",
                    "format": "time_series",
                    "interval": "",
                    "intervalFactor": 1,
                    "legendFormat": "",
                    "refId": "A"
                  }
                ],
                "title": "jaeger_agent_thrift_udp_server_packets_dropped/sec",
                "type": "timeseries"
              },
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "fieldConfig": {
                  "defaults": {
                    "color": {
                      "mode": "palette-classic"
                    },
                    "custom": {
                      "axisCenteredZero": false,
                      "axisColorMode": "text",
                      "axisLabel": "",
                      "axisPlacement": "auto",
                      "barAlignment": 0,
                      "drawStyle": "line",
                      "fillOpacity": 10,
                      "gradientMode": "none",
                      "hideFrom": {
                        "legend": false,
                        "tooltip": false,
                        "viz": false
                      },
                      "lineInterpolation": "linear",
                      "lineWidth": 1,
                      "pointSize": 5,
                      "scaleDistribution": {
                        "type": "linear"
                      },
                      "showPoints": "never",
                      "spanNulls": false,
                      "stacking": {
                        "group": "A",
                        "mode": "none"
                      },
                      "thresholdsStyle": {
                        "mode": "off"
                      }
                    },
                    "links": [],
                    "mappings": [],
                    "thresholds": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "red",
                          "value": 80
                        }
                      ]
                    },
                    "unit": "short"
                  },
                  "overrides": []
                },
                "gridPos": {
                  "h": 6,
                  "w": 8,
                  "x": 16,
                  "y": 8
                },
                "id": 28,
                "links": [],
                "options": {
                  "legend": {
                    "calcs": [],
                    "displayMode": "list",
                    "placement": "bottom",
                    "showLegend": true
                  },
                  "tooltip": {
                    "mode": "multi",
                    "sort": "none"
                  }
                },
                "pluginVersion": "9.3.8",
                "targets": [
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_thrift_udp_t_processor_handler_errors_total[5m])) by (protocol)",
                    "format": "time_series",
                    "interval": "",
                    "intervalFactor": 1,
                    "legendFormat": "",
                    "refId": "A"
                  }
                ],
                "title": "jaeger_agent_thrift_udp_t_processor_handler_errors/sec",
                "type": "timeseries"
              },
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "fieldConfig": {
                  "defaults": {
                    "color": {
                      "mode": "palette-classic"
                    },
                    "custom": {
                      "axisCenteredZero": false,
                      "axisColorMode": "text",
                      "axisLabel": "",
                      "axisPlacement": "auto",
                      "barAlignment": 0,
                      "drawStyle": "line",
                      "fillOpacity": 10,
                      "gradientMode": "none",
                      "hideFrom": {
                        "legend": false,
                        "tooltip": false,
                        "viz": false
                      },
                      "lineInterpolation": "linear",
                      "lineWidth": 1,
                      "pointSize": 5,
                      "scaleDistribution": {
                        "type": "linear"
                      },
                      "showPoints": "never",
                      "spanNulls": false,
                      "stacking": {
                        "group": "A",
                        "mode": "none"
                      },
                      "thresholdsStyle": {
                        "mode": "off"
                      }
                    },
                    "links": [],
                    "mappings": [],
                    "thresholds": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "red",
                          "value": 80
                        }
                      ]
                    },
                    "unit": "short"
                  },
                  "overrides": []
                },
                "gridPos": {
                  "h": 6,
                  "w": 8,
                  "x": 0,
                  "y": 14
                },
                "id": 6,
                "links": [],
                "options": {
                  "legend": {
                    "calcs": [],
                    "displayMode": "list",
                    "placement": "bottom",
                    "showLegend": true
                  },
                  "tooltip": {
                    "mode": "multi",
                    "sort": "none"
                  }
                },
                "pluginVersion": "9.3.8",
                "targets": [
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_agent_reporter_batches_submitted_total[5m])) by (format)",
                    "format": "time_series",
                    "hide": false,
                    "intervalFactor": 1,
                    "legendFormat": "",
                    "refId": "A"
                  }
                ],
                "title": "jaeger_agent_tchannel_reporter_batches_submitted/sec",
                "type": "timeseries"
              },
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "fieldConfig": {
                  "defaults": {
                    "color": {
                      "mode": "palette-classic"
                    },
                    "custom": {
                      "axisCenteredZero": false,
                      "axisColorMode": "text",
                      "axisLabel": "",
                      "axisPlacement": "auto",
                      "barAlignment": 0,
                      "drawStyle": "line",
                      "fillOpacity": 10,
                      "gradientMode": "none",
                      "hideFrom": {
                        "legend": false,
                        "tooltip": false,
                        "viz": false
                      },
                      "lineInterpolation": "linear",
                      "lineWidth": 1,
                      "pointSize": 5,
                      "scaleDistribution": {
                        "type": "linear"
                      },
                      "showPoints": "never",
                      "spanNulls": false,
                      "stacking": {
                        "group": "A",
                        "mode": "none"
                      },
                      "thresholdsStyle": {
                        "mode": "off"
                      }
                    },
                    "links": [],
                    "mappings": [],
                    "thresholds": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "red",
                          "value": 80
                        }
                      ]
                    },
                    "unit": "short"
                  },
                  "overrides": []
                },
                "gridPos": {
                  "h": 6,
                  "w": 8,
                  "x": 8,
                  "y": 14
                },
                "id": 16,
                "links": [],
                "options": {
                  "legend": {
                    "calcs": [],
                    "displayMode": "list",
                    "placement": "bottom",
                    "showLegend": true
                  },
                  "tooltip": {
                    "mode": "multi",
                    "sort": "none"
                  }
                },
                "pluginVersion": "9.3.8",
                "targets": [
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_agent_reporter_spans_submitted_total[5m])) by (format)",
                    "format": "time_series",
                    "intervalFactor": 1,
                    "refId": "A"
                  }
                ],
                "title": "jaeger_agent_tchannel_reporter_spans_submitted/sec",
                "type": "timeseries"
              },
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "fieldConfig": {
                  "defaults": {
                    "color": {
                      "mode": "palette-classic"
                    },
                    "custom": {
                      "axisCenteredZero": false,
                      "axisColorMode": "text",
                      "axisLabel": "",
                      "axisPlacement": "auto",
                      "barAlignment": 0,
                      "drawStyle": "line",
                      "fillOpacity": 10,
                      "gradientMode": "none",
                      "hideFrom": {
                        "legend": false,
                        "tooltip": false,
                        "viz": false
                      },
                      "lineInterpolation": "linear",
                      "lineWidth": 1,
                      "pointSize": 5,
                      "scaleDistribution": {
                        "type": "linear"
                      },
                      "showPoints": "never",
                      "spanNulls": false,
                      "stacking": {
                        "group": "A",
                        "mode": "none"
                      },
                      "thresholdsStyle": {
                        "mode": "off"
                      }
                    },
                    "links": [],
                    "mappings": [],
                    "thresholds": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "red",
                          "value": 80
                        }
                      ]
                    },
                    "unit": "short"
                  },
                  "overrides": []
                },
                "gridPos": {
                  "h": 6,
                  "w": 8,
                  "x": 16,
                  "y": 14
                },
                "id": 12,
                "links": [],
                "options": {
                  "legend": {
                    "calcs": [],
                    "displayMode": "list",
                    "placement": "bottom",
                    "showLegend": true
                  },
                  "tooltip": {
                    "mode": "multi",
                    "sort": "none"
                  }
                },
                "pluginVersion": "9.3.8",
                "targets": [
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "avg(jaeger_agent_reporter_batch_size) by (format)",
                    "format": "time_series",
                    "intervalFactor": 1,
                    "refId": "A"
                  }
                ],
                "title": "avg(jaeger_agent_tchannel_reporter_batch_size)",
                "type": "timeseries"
              },
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "fieldConfig": {
                  "defaults": {
                    "color": {
                      "mode": "palette-classic"
                    },
                    "custom": {
                      "axisCenteredZero": false,
                      "axisColorMode": "text",
                      "axisLabel": "",
                      "axisPlacement": "auto",
                      "barAlignment": 0,
                      "drawStyle": "line",
                      "fillOpacity": 10,
                      "gradientMode": "none",
                      "hideFrom": {
                        "legend": false,
                        "tooltip": false,
                        "viz": false
                      },
                      "lineInterpolation": "linear",
                      "lineWidth": 1,
                      "pointSize": 5,
                      "scaleDistribution": {
                        "type": "linear"
                      },
                      "showPoints": "never",
                      "spanNulls": false,
                      "stacking": {
                        "group": "A",
                        "mode": "none"
                      },
                      "thresholdsStyle": {
                        "mode": "off"
                      }
                    },
                    "links": [],
                    "mappings": [],
                    "thresholds": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "red",
                          "value": 80
                        }
                      ]
                    },
                    "unit": "short"
                  },
                  "overrides": []
                },
                "gridPos": {
                  "h": 6,
                  "w": 8,
                  "x": 0,
                  "y": 20
                },
                "id": 4,
                "links": [],
                "options": {
                  "legend": {
                    "calcs": [],
                    "displayMode": "list",
                    "placement": "bottom",
                    "showLegend": true
                  },
                  "tooltip": {
                    "mode": "multi",
                    "sort": "none"
                  }
                },
                "pluginVersion": "9.3.8",
                "targets": [
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_http_server_requests_total[5m])) by (type)",
                    "format": "time_series",
                    "interval": "",
                    "intervalFactor": 1,
                    "legendFormat": "",
                    "refId": "A"
                  }
                ],
                "title": "jaeger_agent_http_server_requests/sec",
                "type": "timeseries"
              },
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "fieldConfig": {
                  "defaults": {
                    "color": {
                      "mode": "palette-classic"
                    },
                    "custom": {
                      "axisCenteredZero": false,
                      "axisColorMode": "text",
                      "axisLabel": "",
                      "axisPlacement": "auto",
                      "barAlignment": 0,
                      "drawStyle": "line",
                      "fillOpacity": 10,
                      "gradientMode": "none",
                      "hideFrom": {
                        "legend": false,
                        "tooltip": false,
                        "viz": false
                      },
                      "lineInterpolation": "linear",
                      "lineWidth": 1,
                      "pointSize": 5,
                      "scaleDistribution": {
                        "type": "linear"
                      },
                      "showPoints": "never",
                      "spanNulls": false,
                      "stacking": {
                        "group": "A",
                        "mode": "none"
                      },
                      "thresholdsStyle": {
                        "mode": "off"
                      }
                    },
                    "links": [],
                    "mappings": [],
                    "thresholds": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "red",
                          "value": 80
                        }
                      ]
                    },
                    "unit": "short"
                  },
                  "overrides": []
                },
                "gridPos": {
                  "h": 6,
                  "w": 8,
                  "x": 8,
                  "y": 20
                },
                "id": 14,
                "links": [],
                "options": {
                  "legend": {
                    "calcs": [],
                    "displayMode": "list",
                    "placement": "bottom",
                    "showLegend": true
                  },
                  "tooltip": {
                    "mode": "multi",
                    "sort": "none"
                  }
                },
                "pluginVersion": "9.3.8",
                "targets": [
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_agent_reporter_batches_failures_total[5m])) by (format)",
                    "format": "time_series",
                    "intervalFactor": 1,
                    "refId": "A"
                  }
                ],
                "title": "jaeger_agent_tchannel_reporter_batches_failures/sec",
                "type": "timeseries"
              },
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "fieldConfig": {
                  "defaults": {
                    "color": {
                      "mode": "palette-classic"
                    },
                    "custom": {
                      "axisCenteredZero": false,
                      "axisColorMode": "text",
                      "axisLabel": "",
                      "axisPlacement": "auto",
                      "barAlignment": 0,
                      "drawStyle": "line",
                      "fillOpacity": 10,
                      "gradientMode": "none",
                      "hideFrom": {
                        "legend": false,
                        "tooltip": false,
                        "viz": false
                      },
                      "lineInterpolation": "linear",
                      "lineWidth": 1,
                      "pointSize": 5,
                      "scaleDistribution": {
                        "type": "linear"
                      },
                      "showPoints": "never",
                      "spanNulls": false,
                      "stacking": {
                        "group": "A",
                        "mode": "none"
                      },
                      "thresholdsStyle": {
                        "mode": "off"
                      }
                    },
                    "links": [],
                    "mappings": [],
                    "thresholds": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "red",
                          "value": 80
                        }
                      ]
                    },
                    "unit": "short"
                  },
                  "overrides": []
                },
                "gridPos": {
                  "h": 6,
                  "w": 8,
                  "x": 16,
                  "y": 20
                },
                "id": 18,
                "links": [],
                "options": {
                  "legend": {
                    "calcs": [],
                    "displayMode": "list",
                    "placement": "bottom",
                    "showLegend": true
                  },
                  "tooltip": {
                    "mode": "multi",
                    "sort": "none"
                  }
                },
                "pluginVersion": "9.3.8",
                "targets": [
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_agent_reporter_spans_failures_total[5m])) by (format)",
                    "format": "time_series",
                    "intervalFactor": 1,
                    "refId": "A"
                  }
                ],
                "title": "jaeger_agent_tchannel_reporter_spans_failures/sec",
                "type": "timeseries"
              },
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "fieldConfig": {
                  "defaults": {
                    "color": {
                      "mode": "palette-classic"
                    },
                    "custom": {
                      "axisCenteredZero": false,
                      "axisColorMode": "text",
                      "axisLabel": "",
                      "axisPlacement": "auto",
                      "barAlignment": 0,
                      "drawStyle": "line",
                      "fillOpacity": 10,
                      "gradientMode": "none",
                      "hideFrom": {
                        "legend": false,
                        "tooltip": false,
                        "viz": false
                      },
                      "lineInterpolation": "linear",
                      "lineWidth": 1,
                      "pointSize": 5,
                      "scaleDistribution": {
                        "type": "linear"
                      },
                      "showPoints": "never",
                      "spanNulls": false,
                      "stacking": {
                        "group": "A",
                        "mode": "none"
                      },
                      "thresholdsStyle": {
                        "mode": "off"
                      }
                    },
                    "links": [],
                    "mappings": [],
                    "thresholds": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "red",
                          "value": 80
                        }
                      ]
                    },
                    "unit": "short"
                  },
                  "overrides": []
                },
                "gridPos": {
                  "h": 6,
                  "w": 8,
                  "x": 0,
                  "y": 26
                },
                "id": 2,
                "links": [],
                "options": {
                  "legend": {
                    "calcs": [],
                    "displayMode": "list",
                    "placement": "bottom",
                    "showLegend": true
                  },
                  "tooltip": {
                    "mode": "multi",
                    "sort": "none"
                  }
                },
                "pluginVersion": "9.3.8",
                "targets": [
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_http_server_errors_total[5m])) by (source, status)",
                    "format": "time_series",
                    "interval": "",
                    "intervalFactor": 1,
                    "legendFormat": "{{source}}.{{status}}",
                    "refId": "A"
                  }
                ],
                "title": "jaeger_agent_http_server_errors/sec",
                "type": "timeseries"
              },
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "fieldConfig": {
                  "defaults": {
                    "color": {
                      "mode": "palette-classic"
                    },
                    "custom": {
                      "axisCenteredZero": false,
                      "axisColorMode": "text",
                      "axisLabel": "",
                      "axisPlacement": "auto",
                      "barAlignment": 0,
                      "drawStyle": "line",
                      "fillOpacity": 10,
                      "gradientMode": "none",
                      "hideFrom": {
                        "legend": false,
                        "tooltip": false,
                        "viz": false
                      },
                      "lineInterpolation": "linear",
                      "lineWidth": 1,
                      "pointSize": 5,
                      "scaleDistribution": {
                        "type": "linear"
                      },
                      "showPoints": "never",
                      "spanNulls": false,
                      "stacking": {
                        "group": "A",
                        "mode": "none"
                      },
                      "thresholdsStyle": {
                        "mode": "off"
                      }
                    },
                    "links": [],
                    "mappings": [],
                    "thresholds": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "red",
                          "value": 80
                        }
                      ]
                    },
                    "unit": "short"
                  },
                  "overrides": []
                },
                "gridPos": {
                  "h": 6,
                  "w": 16,
                  "x": 8,
                  "y": 26
                },
                "id": 10,
                "links": [],
                "options": {
                  "legend": {
                    "calcs": [],
                    "displayMode": "list",
                    "placement": "bottom",
                    "showLegend": true
                  },
                  "tooltip": {
                    "mode": "multi",
                    "sort": "none"
                  }
                },
                "pluginVersion": "9.3.8",
                "targets": [
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(jaeger_agent_collector_proxy_total) by (endpoint,protocol,result)",
                    "format": "time_series",
                    "intervalFactor": 1,
                    "refId": "A"
                  }
                ],
                "title": "total(jaeger_agent_collector_proxy)",
                "type": "timeseries"
              }
            ],
            "targets": [
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "refId": "A"
              }
            ],
            "title": "Jaeger Agent",
            "type": "row"
          },
          {
            "collapsed": true,
            "datasource": {
              "type": "prometheus",
              "uid": "prometheus"
            },
            "gridPos": {
              "h": 1,
              "w": 24,
              "x": 0,
              "y": 32
            },
            "id": 46,
            "panels": [
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "fieldConfig": {
                  "defaults": {
                    "color": {
                      "mode": "palette-classic"
                    },
                    "custom": {
                      "axisCenteredZero": false,
                      "axisColorMode": "text",
                      "axisLabel": "",
                      "axisPlacement": "auto",
                      "barAlignment": 0,
                      "drawStyle": "line",
                      "fillOpacity": 10,
                      "gradientMode": "none",
                      "hideFrom": {
                        "legend": false,
                        "tooltip": false,
                        "viz": false
                      },
                      "lineInterpolation": "linear",
                      "lineWidth": 1,
                      "pointSize": 5,
                      "scaleDistribution": {
                        "type": "linear"
                      },
                      "showPoints": "never",
                      "spanNulls": false,
                      "stacking": {
                        "group": "A",
                        "mode": "none"
                      },
                      "thresholdsStyle": {
                        "mode": "off"
                      }
                    },
                    "links": [],
                    "mappings": [],
                    "thresholds": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "red",
                          "value": 80
                        }
                      ]
                    },
                    "unit": "short"
                  },
                  "overrides": []
                },
                "gridPos": {
                  "h": 7,
                  "w": 24,
                  "x": 0,
                  "y": 3
                },
                "id": 48,
                "links": [],
                "options": {
                  "legend": {
                    "calcs": [],
                    "displayMode": "list",
                    "placement": "bottom",
                    "showLegend": true
                  },
                  "tooltip": {
                    "mode": "multi",
                    "sort": "none"
                  }
                },
                "pluginVersion": "9.3.8",
                "targets": [
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "(jaeger_rpc_request_latency_sum / jaeger_rpc_request_latency_count)*1000",
                    "format": "time_series",
                    "intervalFactor": 1,
                    "legendFormat": "",
                    "refId": "A"
                  }
                ],
                "title": "Average request latency (milliseconds)",
                "type": "timeseries"
              },
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "fieldConfig": {
                  "defaults": {
                    "color": {
                      "mode": "palette-classic"
                    },
                    "custom": {
                      "axisCenteredZero": false,
                      "axisColorMode": "text",
                      "axisLabel": "",
                      "axisPlacement": "auto",
                      "barAlignment": 0,
                      "drawStyle": "line",
                      "fillOpacity": 10,
                      "gradientMode": "none",
                      "hideFrom": {
                        "legend": false,
                        "tooltip": false,
                        "viz": false
                      },
                      "lineInterpolation": "linear",
                      "lineWidth": 1,
                      "pointSize": 5,
                      "scaleDistribution": {
                        "type": "linear"
                      },
                      "showPoints": "never",
                      "spanNulls": false,
                      "stacking": {
                        "group": "A",
                        "mode": "none"
                      },
                      "thresholdsStyle": {
                        "mode": "off"
                      }
                    },
                    "links": [],
                    "mappings": [],
                    "thresholds": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "red",
                          "value": 80
                        }
                      ]
                    },
                    "unit": "short"
                  },
                  "overrides": []
                },
                "gridPos": {
                  "h": 7,
                  "w": 8,
                  "x": 0,
                  "y": 10
                },
                "id": 50,
                "links": [],
                "options": {
                  "legend": {
                    "calcs": [],
                    "displayMode": "list",
                    "placement": "bottom",
                    "showLegend": true
                  },
                  "tooltip": {
                    "mode": "multi",
                    "sort": "none"
                  }
                },
                "pluginVersion": "9.3.8",
                "targets": [
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_rpc_http_requests_total[5m]))*60",
                    "format": "time_series",
                    "hide": false,
                    "intervalFactor": 1,
                    "legendFormat": "All requests (/min)",
                    "refId": "A"
                  },
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_rpc_http_requests_total{status_code=~\"2xx\"}[5m]))*60",
                    "format": "time_series",
                    "intervalFactor": 1,
                    "legendFormat": "2xx Requests (/min)",
                    "refId": "B"
                  },
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_rpc_http_requests_total{status_code!=\"2xx\"}[5m]))*60",
                    "format": "time_series",
                    "intervalFactor": 1,
                    "legendFormat": "Non-2xx Requests (/min)",
                    "refId": "C"
                  }
                ],
                "title": "Requests/min (All requests)",
                "type": "timeseries"
              },
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "fieldConfig": {
                  "defaults": {
                    "color": {
                      "mode": "palette-classic"
                    },
                    "custom": {
                      "axisCenteredZero": false,
                      "axisColorMode": "text",
                      "axisLabel": "",
                      "axisPlacement": "auto",
                      "barAlignment": 0,
                      "drawStyle": "line",
                      "fillOpacity": 10,
                      "gradientMode": "none",
                      "hideFrom": {
                        "legend": false,
                        "tooltip": false,
                        "viz": false
                      },
                      "lineInterpolation": "linear",
                      "lineWidth": 1,
                      "pointSize": 5,
                      "scaleDistribution": {
                        "type": "linear"
                      },
                      "showPoints": "never",
                      "spanNulls": false,
                      "stacking": {
                        "group": "A",
                        "mode": "none"
                      },
                      "thresholdsStyle": {
                        "mode": "off"
                      }
                    },
                    "links": [],
                    "mappings": [],
                    "thresholds": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "red",
                          "value": 80
                        }
                      ]
                    },
                    "unit": "short"
                  },
                  "overrides": []
                },
                "gridPos": {
                  "h": 7,
                  "w": 8,
                  "x": 8,
                  "y": 10
                },
                "id": 52,
                "links": [],
                "options": {
                  "legend": {
                    "calcs": [],
                    "displayMode": "list",
                    "placement": "bottom",
                    "showLegend": true
                  },
                  "tooltip": {
                    "mode": "multi",
                    "sort": "none"
                  }
                },
                "pluginVersion": "9.3.8",
                "targets": [
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_rpc_http_requests_total{endpoint=~\"/api/traces\"}[5m]))*60",
                    "format": "time_series",
                    "intervalFactor": 1,
                    "legendFormat": "All requests (/min)",
                    "refId": "A"
                  },
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_rpc_http_requests_total{endpoint=~\"/api/traces\",status_code=~\"2xx\"}[5m]))*60",
                    "format": "time_series",
                    "intervalFactor": 1,
                    "legendFormat": "2xx Requests (/min)",
                    "refId": "B"
                  },
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_rpc_http_requests_total{endpoint=~\"/api/traces\",status_code!=\"2xx\"}[5m]))*60",
                    "format": "time_series",
                    "intervalFactor": 1,
                    "legendFormat": "Non-2xx Requests (/min)",
                    "refId": "C"
                  }
                ],
                "title": "Requests/min (endpoint=\"/api/traces\")",
                "type": "timeseries"
              },
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "fieldConfig": {
                  "defaults": {
                    "color": {
                      "mode": "palette-classic"
                    },
                    "custom": {
                      "axisCenteredZero": false,
                      "axisColorMode": "text",
                      "axisLabel": "",
                      "axisPlacement": "auto",
                      "barAlignment": 0,
                      "drawStyle": "line",
                      "fillOpacity": 10,
                      "gradientMode": "none",
                      "hideFrom": {
                        "legend": false,
                        "tooltip": false,
                        "viz": false
                      },
                      "lineInterpolation": "linear",
                      "lineWidth": 1,
                      "pointSize": 5,
                      "scaleDistribution": {
                        "type": "linear"
                      },
                      "showPoints": "never",
                      "spanNulls": false,
                      "stacking": {
                        "group": "A",
                        "mode": "none"
                      },
                      "thresholdsStyle": {
                        "mode": "off"
                      }
                    },
                    "links": [],
                    "mappings": [],
                    "thresholds": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "red",
                          "value": 80
                        }
                      ]
                    },
                    "unit": "short"
                  },
                  "overrides": []
                },
                "gridPos": {
                  "h": 7,
                  "w": 8,
                  "x": 16,
                  "y": 10
                },
                "id": 54,
                "links": [],
                "options": {
                  "legend": {
                    "calcs": [],
                    "displayMode": "list",
                    "placement": "bottom",
                    "showLegend": true
                  },
                  "tooltip": {
                    "mode": "multi",
                    "sort": "none"
                  }
                },
                "pluginVersion": "9.3.8",
                "targets": [
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_rpc_http_requests_total{endpoint=~\"/api/traces/-traceID-\"}[5m]))*60",
                    "format": "time_series",
                    "interval": "",
                    "intervalFactor": 1,
                    "legendFormat": "All requests (/min)",
                    "refId": "A"
                  },
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_rpc_http_requests_total{endpoint=~\"/api/traces/-traceID-\",status_code=~\"2xx\"}[5m]))*60",
                    "format": "time_series",
                    "intervalFactor": 1,
                    "legendFormat": "2xx Requests (/min)",
                    "refId": "B"
                  },
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_rpc_http_requests_total{endpoint=~\"/api/traces/-traceID-\",status_code!=\"2xx\"}[5m]))*60",
                    "format": "time_series",
                    "intervalFactor": 1,
                    "legendFormat": "Non-2xx Requests (/min)",
                    "refId": "C"
                  }
                ],
                "title": "Requests/min (endpoint=\"/api/traces/-traceID-\")",
                "type": "timeseries"
              },
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "fieldConfig": {
                  "defaults": {
                    "color": {
                      "mode": "palette-classic"
                    },
                    "custom": {
                      "axisCenteredZero": false,
                      "axisColorMode": "text",
                      "axisLabel": "",
                      "axisPlacement": "auto",
                      "barAlignment": 0,
                      "drawStyle": "line",
                      "fillOpacity": 10,
                      "gradientMode": "none",
                      "hideFrom": {
                        "legend": false,
                        "tooltip": false,
                        "viz": false
                      },
                      "lineInterpolation": "linear",
                      "lineWidth": 1,
                      "pointSize": 5,
                      "scaleDistribution": {
                        "type": "linear"
                      },
                      "showPoints": "never",
                      "spanNulls": false,
                      "stacking": {
                        "group": "A",
                        "mode": "none"
                      },
                      "thresholdsStyle": {
                        "mode": "off"
                      }
                    },
                    "links": [],
                    "mappings": [],
                    "thresholds": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "red",
                          "value": 80
                        }
                      ]
                    },
                    "unit": "short"
                  },
                  "overrides": []
                },
                "gridPos": {
                  "h": 8,
                  "w": 12,
                  "x": 0,
                  "y": 17
                },
                "id": 56,
                "links": [],
                "options": {
                  "legend": {
                    "calcs": [],
                    "displayMode": "list",
                    "placement": "bottom",
                    "showLegend": true
                  },
                  "tooltip": {
                    "mode": "multi",
                    "sort": "none"
                  }
                },
                "pluginVersion": "9.3.8",
                "targets": [
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_rpc_http_requests_total{endpoint=~\"/api/services/-service-/operations\"}[5m]))*60",
                    "format": "time_series",
                    "intervalFactor": 1,
                    "legendFormat": "All requests (/min)",
                    "refId": "A"
                  },
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_rpc_http_requests_total{endpoint=~\"/api/services/-service-/operations\",status_code=~\"2xx\"}[5m]))*60",
                    "format": "time_series",
                    "intervalFactor": 1,
                    "legendFormat": "2xx Requests (/min)",
                    "refId": "B"
                  },
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_rpc_http_requests_total{endpoint=~\"/api/services/-service-/operations\",status_code!=\"2xx\"}[5m]))*60",
                    "format": "time_series",
                    "intervalFactor": 1,
                    "legendFormat": "Non-2xx Requests (/min)",
                    "refId": "C"
                  }
                ],
                "title": "Requests/min (endpoint=\"/api/services/-service-/operations\")",
                "type": "timeseries"
              },
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "fieldConfig": {
                  "defaults": {
                    "color": {
                      "mode": "palette-classic"
                    },
                    "custom": {
                      "axisCenteredZero": false,
                      "axisColorMode": "text",
                      "axisLabel": "",
                      "axisPlacement": "auto",
                      "barAlignment": 0,
                      "drawStyle": "line",
                      "fillOpacity": 10,
                      "gradientMode": "none",
                      "hideFrom": {
                        "legend": false,
                        "tooltip": false,
                        "viz": false
                      },
                      "lineInterpolation": "linear",
                      "lineWidth": 1,
                      "pointSize": 5,
                      "scaleDistribution": {
                        "type": "linear"
                      },
                      "showPoints": "never",
                      "spanNulls": false,
                      "stacking": {
                        "group": "A",
                        "mode": "none"
                      },
                      "thresholdsStyle": {
                        "mode": "off"
                      }
                    },
                    "links": [],
                    "mappings": [],
                    "thresholds": {
                      "mode": "absolute",
                      "steps": [
                        {
                          "color": "green"
                        },
                        {
                          "color": "red",
                          "value": 80
                        }
                      ]
                    },
                    "unit": "short"
                  },
                  "overrides": []
                },
                "gridPos": {
                  "h": 8,
                  "w": 12,
                  "x": 12,
                  "y": 17
                },
                "id": 58,
                "links": [],
                "options": {
                  "legend": {
                    "calcs": [],
                    "displayMode": "list",
                    "placement": "bottom",
                    "showLegend": true
                  },
                  "tooltip": {
                    "mode": "multi",
                    "sort": "none"
                  }
                },
                "pluginVersion": "9.3.8",
                "targets": [
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "editorMode": "code",
                    "expr": "sum(rate(jaeger_rpc_http_requests_total{endpoint=~\"/api/services\"}[5m]))*60",
                    "format": "time_series",
                    "intervalFactor": 1,
                    "legendFormat": "All requests (/min)",
                    "range": true,
                    "refId": "A"
                  },
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_rpc_http_requests_total{endpoint=~\"/api/services\",status_code=~\"2xx\"}[5m]))*60",
                    "format": "time_series",
                    "intervalFactor": 1,
                    "legendFormat": "2xx Requests (/min)",
                    "refId": "B"
                  },
                  {
                    "datasource": {
                      "type": "prometheus",
                      "uid": "prometheus"
                    },
                    "expr": "sum(rate(jaeger_rpc_http_requests_total{endpoint=~\"/api/services\",status_code!=\"2xx\"}[5m]))*60",
                    "format": "time_series",
                    "intervalFactor": 1,
                    "legendFormat": "Non-2xx Requests (/min)",
                    "refId": "C"
                  }
                ],
                "title": "Requests/min (endpoint=\"/api/services\")",
                "type": "timeseries"
              }
            ],
            "targets": [
              {
                "datasource": {
                  "type": "prometheus",
                  "uid": "prometheus"
                },
                "refId": "A"
              }
            ],
            "title": "Jaeger Query",
            "type": "row"
          }
        ],
        "refresh": false,
        "schemaVersion": 37,
        "style": "dark",
        "tags": [
          "jaeger",
          "jaeger-all-in-one"
        ],
        "templating": {
          "list": [
            {
              "current": {
                "selected": false,
                "text": "customer",
                "value": "customer"
              },
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "definition": "label_values(svc)",
              "hide": 0,
              "includeAll": false,
              "label": "serviceName",
              "multi": false,
              "name": "svc",
              "options": [],
              "query": {
                "query": "label_values(svc)",
                "refId": "Prometheus-svc-Variable-Query"
              },
              "refresh": 2,
              "regex": "",
              "skipUrlSync": false,
              "sort": 0,
              "tagValuesQuery": "",
              "tagsQuery": "",
              "type": "query",
              "useTags": false
            }
          ]
        },
        "time": {
          "from": "now-1m",
          "to": "now"
        },
        "timepicker": {
          "refresh_intervals": [
            "10s",
            "30s",
            "1m",
            "5m",
            "15m",
            "30m",
            "1h",
            "2h",
            "1d"
          ],
          "time_options": [
            "5m",
            "15m",
            "1h",
            "6h",
            "12h",
            "24h",
            "2d",
            "7d",
            "30d"
          ]
        },
        "timezone": "",
        "title": "Jaeger-all-in-one / Overview",
        "uid": "zLOi95xmke",
        "version": 5,
        "weekStart": ""
      }
EOF

jaeger_exposed_svc_name=jaeger-query-external
jaeger_target_nodeport=30002
echo "[INFO] exposing jaeger-query externally"
kubectl expose deployment jaeger \
  --port 16686 \
  --type NodePort \
  --name "${jaeger_exposed_svc_name}"

echo "[INFO] set ${jaeger_exposed_svc_name} port to ${jaeger_target_nodeport}"
kubectl patch service "${jaeger_exposed_svc_name}" \
  --type='json' \
  --patch='[{"op": "replace", "path": "/spec/ports/0/nodePort", "value":'"${jaeger_target_nodeport}"'}]'

echo "[INFO] congratulations! you can now access:"
echo "  * hotrod app at http://localhost:${hotrod_target_nodeport} (Press CTRL + link to open)"
echo "  * jaeger at http://localhost:${jaeger_target_nodeport} (Press CTRL + link to open)"

echo "[INFO] after you test hotrod application if you wish to delete hotrod application you can run the following command:"
echo " -> without jaeger:"
echo "    $ kubectl delete svc hotrod hotrod-external; kubectl delete deployments hotrod"
echo " -> with jaeger:"
echo "    $ kubectl delete svc hotrod hotrod-external jaeger-query-external; kubectl delete deployments hotrod; kubectl delete jaeger jaeger"
