# SundayApp - Kubernetes Operator Project

A Kubernetes operator project demonstrating custom resource management with self-healing capabilities. Built in two parts:
- **Part A**: EtherealPod - A custom Kubernetes operator that manages Pod lifecycle
- **Part B**: SundayApp - A Flask-based groceries tracker API

## Prerequisites

### Required Software
- **Kubernetes**: Local cluster (minikube, kind, or Docker Desktop)
- **kubectl**: Kubernetes command-line tool
- **Go**: Version 1.19+ (for Part A)
- **Python**: Version 3.12+ (for Part B)
- **Docker**: For building container images

### Installation Links
- [minikube](https://minikube.sigs.k8s.io/docs/start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Go](https://go.dev/dl/)
- [Python](https://www.python.org/downloads/)
- [Docker](https://docs.docker.com/get-docker/)

---

## Quick Start

### 1. Start Kubernetes Cluster

```bash
# Start minikube
minikube start

# Verify cluster is running
kubectl get nodes
```

### 2. Deploy Part A - EtherealPod Operator

```bash
cd part-a

# Install the CRD
kubectl apply -f crd/etherealpod-crd.yaml

# Verify CRD is installed
kubectl get crd etherealpods.sunday.example.com

# Run the controller locally (keep this terminal running)
go run main.go
```

**Expected output:**
```
INFO    controller-runtime.metrics      Metrics server is starting to listen    {"addr": ":8080"}
INFO    Starting server {"path": "/metrics", "kind": "metrics", "addr": "[::]:8080"}
INFO    Starting EventSource    {"controller": "etherealpod", "source": "kind source: *v1.EtherealPod"}
INFO    Starting Controller     {"controller": "etherealpod"}
```

### 3. Deploy Part B - SundayApp

**Open a new terminal:**

```bash
cd part-b

# Build the Docker image (inside minikube's Docker environment)
eval $(minikube docker-env)
docker build -t sunday-app:latest .

# Deploy PostgreSQL
kubectl apply -f postgres-deployment.yaml

# Wait for PostgreSQL to be ready (about 30 seconds)
kubectl wait --for=condition=ready pod -l app=postgres --timeout=60s

# Deploy the EtherealPod (which creates the Flask app pod)
kubectl apply -f ethernalpod-sunday-app.yaml

# Deploy the Service
kubectl apply -f service.yaml

# Verify everything is running
kubectl get eps,pods,svc
```

**Expected output:**
```
NAME                                        AGE   RESTARTS
etherealpod.sunday.example.com/sunday-app   10s   0

NAME                            READY   STATUS    RESTARTS   AGE
pod/postgres-xxx                1/1     Running   0          30s
pod/sunday-app-xxx              1/1     Running   0          10s

NAME                         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
service/postgres-service     ClusterIP   10.96.0.1      <none>        5432/TCP   30s
service/sunday-app-service   ClusterIP   10.96.0.2      <none>        5000/TCP   10s
```

---

## Testing the API

### Option 1: Run Test Script

```bash
cd part-b

# Run the API test script
./test_api.sh
```

This script will:
- Add products (apples, beer)
- Retrieve amounts
- Update quantities
- Delete products
- Test edge cases

### Option 2: Manual Testing

The API is only accessible from inside the Kubernetes cluster. To test manually:

```bash
# Run a temporary curl pod
kubectl run curl-test --image=curlimages/curl:latest --rm -i -- sh

# Inside the pod, test the API:
curl http://sunday-app-service:5000/health

# Add a product
curl -X POST http://sunday-app-service:5000/write \
  -H "Content-Type: application/json" \
  -d '{"user_id": "loki", "product_name": "apple", "amount": 3}'

# Get amount
curl "http://sunday-app-service:5000/get_product_amount?product_name=apple"

# Delete product
curl -X DELETE "http://sunday-app-service:5000/delete_product?product_name=apple"

# Exit when done
exit
```

---

## Demonstrating Self-Healing

### Demo 1: Pod Deletion Recovery

```bash
cd part-b
./demo-video3a-pod-deletion-no-portforward.sh
```

**What it demonstrates:**
- Deletes the application pod
- EtherealPod controller automatically recreates it
- Data persists in PostgreSQL
- Controller updates status with new pod name

### Demo 2: Crash Recovery & Restart Tracking

```bash
cd part-b
./demo-video3b-crash-recovery-no-portforward.sh
```

**What it demonstrates:**
- Triggers application crash
- Kubernetes restarts the container
- Restart count increments
- EtherealPod controller tracks the restart
- Application recovers automatically

---

## API Endpoints

### GET /get_product_amount
Get total amount of a product across all users.

**Parameters:**
- `product_name` (query string): Product to query

**Example:**
```bash
curl "http://sunday-app-service:5000/get_product_amount?product_name=apple"
```

**Response:**
```json
{"amount": 5}
```

### POST /write
Add or update a product entry.

**Body (JSON):**
- `user_id`: User identifier (lowercase)
- `product_name`: Product name (lowercase)
- `amount`: Quantity (positive integer)

**Example:**
```bash
curl -X POST http://sunday-app-service:5000/write \
  -H "Content-Type: application/json" \
  -d '{"user_id": "loki", "product_name": "apple", "amount": 3}'
```

**Response:**
```json
{"user_id": "loki", "product_name": "apple", "amount": 3}
```

### DELETE /delete_product
Remove all entries for a product.

**Parameters:**
- `product_name` (query string): Product to delete

**Example:**
```bash
curl -X DELETE "http://sunday-app-service:5000/delete_product?product_name=apple"
```

**Response:**
```json
{"product_name": "apple", "deleted_rows": 2}
```

---

## Architecture

### Part A: EtherealPod Operator

**Components:**
- `etherealpod_types.go`: Defines the EtherealPod custom resource structure
- `etherealpod_controller.go`: Implements the controller logic
- `etherealpod-crd.yaml`: Kubernetes Custom Resource Definition

**Key Features:**
- Watches EtherealPod resources
- Creates and manages Pods based on template spec
- Ensures exactly one Pod exists at a time
- Tracks container restart counts
- Automatically recreates failed/deleted Pods

### Part B: SundayApp API

**Components:**
- `app.py`: Flask application with API endpoints
- `models.py`: SQLAlchemy database model
- `db.py`: Database connection management
- `postgres-deployment.yaml`: PostgreSQL setup with persistence
- `ethernalpod-sunday-app.yaml`: EtherealPod resource for the Flask app
- `service.yaml`: Kubernetes Service for networking

**Data Model:**
- Composite key: `(user_id, product_name)`
- Accumulates amounts for same user-product combination
- PostgreSQL for data persistence

---

## Cleanup

To remove everything:

```bash
# Delete Part B resources
kubectl delete -f part-b/service.yaml
kubectl delete -f part-b/ethernalpod-sunday-app.yaml
kubectl delete -f part-b/postgres-deployment.yaml

# Delete Part A CRD (this removes all EtherealPods)
kubectl delete -f part-a/crd/etherealpod-crd.yaml

# Stop the controller (Ctrl+C in the terminal running main.go)

# Stop minikube (optional)
minikube stop
```

---

## Troubleshooting

### Pod not starting
```bash
# Check pod logs
kubectl logs -l app=sunday-app

# Check pod events
kubectl describe pod -l app=sunday-app
```

### Controller not seeing resources
```bash
# Verify CRD is installed
kubectl get crd etherealpods.sunday.example.com

# Check controller is running
# Should see reconciliation logs in the terminal
```

### Cannot connect to API
```bash
# Verify Service exists
kubectl get svc sunday-app-service

# Verify Pod is running
kubectl get pods -l app=sunday-app

# Check if PostgreSQL is ready
kubectl get pods -l app=postgres
```

### Image pull errors
```bash
# Make sure you're using minikube's Docker environment
eval $(minikube docker-env)

# Rebuild the image
cd part-b
docker build -t sunday-app:latest .

# Verify image exists
docker images | grep sunday-app
```

---

## Project Structure

```
SundayApp/
├── part-a/                          # EtherealPod Operator
│   ├── main.go                      # Entry point
│   ├── go.mod, go.sum              # Go dependencies
│   ├── api/v1/
│   │   └── etherealpod_types.go    # CRD types
│   ├── controllers/
│   │   └── etherealpod_controller.go # Controller logic
│   └── crd/
│       └── etherealpod-crd.yaml    # CRD manifest
│
└── part-b/                          # SundayApp API
    ├── app.py                       # Flask application
    ├── app/
    │   ├── models.py                # Database model
    │   └── db.py                    # Database connection
    ├── requirements.txt             # Python dependencies
    ├── Dockerfile                   # Container image
    ├── ethernalpod-sunday-app.yaml  # EtherealPod resource
    ├── service.yaml                 # Kubernetes Service
    ├── postgres-deployment.yaml     # PostgreSQL setup
    ├── test_api.sh                  # API test script
    ├── demo-video3a-pod-deletion-no-portforward.sh
    └── demo-video3b-crash-recovery-no-portforward.sh
```

---

## Key Concepts Demonstrated

1. **Custom Resource Definitions (CRD)**: Extending Kubernetes with EtherealPod
2. **Operators**: Controller pattern for managing application lifecycle
3. **Self-Healing**: Automatic pod recreation and crash recovery
4. **Persistence**: Data survives pod restarts using PostgreSQL
5. **Service Discovery**: Using Kubernetes Services for stable networking
6. **Labels & Selectors**: Connecting Services to Pods

---

## License

This is a demonstration project.
# sunday-app
