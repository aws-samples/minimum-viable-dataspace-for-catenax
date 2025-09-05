---
apiVersion: v1
kind: ConfigMap
metadata:
  name: data-dashboard-nginx-config
  namespace: mvd
data:
  nginx.conf: |
    ${DATA_DASHBOARD_NGINX_CONFIG}

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: data-dashboard-config
  namespace: mvd
data:
  APP_BASE_HREF.txt: "/dashboard"
  app-config.json: |
    ${DATA_DASHBOARD_APP_CONFIG}
  edc-connector-config.json: |
    [
      {
        "connectorName": "Consumer",
        "managementUrl": "https://${NLB_ADDRESS}/consumer/cp/api/management",
        "defaultUrl": "https://${NLB_ADDRESS}/consumer/health/api",
        "protocolUrl": "http://consumer-controlplane:8082/api/dsp",
        "apiToken": "${EDC_AUTH_KEY}",
        "controlUrl": "http://consumer-controlplane:8083/api/control",
        "federatedCatalogEnabled": false,
        "federatedCatalogUrl": "https://${NLB_ADDRESS}/consumer/fc/api/catalog",
        "did": "did:web:consumer-identityhub%3A7083:consumer"
      },
      {
        "connectorName": "Provider Q&A",
        "managementUrl": "https://${NLB_ADDRESS}/provider-qna/cp/api/management",
        "defaultUrl": "https://${NLB_ADDRESS}/provider-qna/health/api",
        "protocolUrl": "http://provider-qna-controlplane:8082/api/dsp",
        "apiToken": "${EDC_AUTH_KEY}",
        "controlUrl": "http://provider-qna-controlplane:8083/api/control",
        "federatedCatalogEnabled": false,
        "federatedCatalogUrl": "https://${NLB_ADDRESS}/provider-qna/fc/api/catalog",
        "did": "did:web:provider-identityhub%3A7083:provider"
      },
      {
        "connectorName": "Provider Manufacturing",
        "managementUrl": "https://${NLB_ADDRESS}/provider-manufacturing/cp/api/management",
        "defaultUrl": "https://${NLB_ADDRESS}/provider-manufacturing/health/api",
        "protocolUrl": "http://provider-manufacturing-controlplane:8082/api/dsp",
        "apiToken": "${EDC_AUTH_KEY}",
        "controlUrl": "http://provider-manufacturing-controlplane:8083/api/control",
        "federatedCatalogEnabled": false,
        "federatedCatalogUrl": "https://${NLB_ADDRESS}/provider-manufacturing/fc/api/catalog",
        "did": "did:web:provider-identityhub%3A7083:provider"
      }
    ]

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-dashboard
  namespace: mvd
  labels:
    app: data-dashboard
spec:
  replicas: 1
  selector:
    matchLabels:
      app: data-dashboard
  template:
    metadata:
      labels:
        app: data-dashboard
    spec:
      containers:
      - name: data-dashboard
        image: "${DATA_DASHBOARD_IMAGE}"
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: config-volume
          mountPath: /app/config
        - name: nginx-config-volume
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: nginx.conf
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: config-volume
        configMap:
          name: data-dashboard-config
      - name: nginx-config-volume
        configMap:
          name: data-dashboard-nginx-config

---
apiVersion: v1
kind: Service
metadata:
  name: data-dashboard
  namespace: mvd
spec:
  selector:
    app: data-dashboard
  ports:
  - port: 8080
    targetPort: 8080
    protocol: TCP
  type: ClusterIP

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: data-dashboard
  namespace: mvd
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /dashboard(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: data-dashboard
            port:
              number: 8080
