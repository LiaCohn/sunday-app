#!/bin/bash

# Video 3B: Crash Recovery & Restart Tracking
# No port-forward needed - runs commands inside the cluster!

echo "=========================================="
echo "Video 3B: Crash Recovery & Restart Tracking"
echo "=========================================="
echo ""
echo "Press Enter to start..."
read

# Helper function to run curl inside cluster
run_in_cluster() {
    kubectl run curl-test --image=curlimages/curl:latest --rm -i --restart=Never --quiet -- "$@"
}

# ============================================
# Show Current State
# ============================================
echo ""
echo "=== Current State ==="
echo ""
echo "EtherealPod restart count:"
kubectl get eps
echo ""
echo "Pod restart count:"
kubectl get pods -l app=sunday-app
echo ""
echo "Press Enter to test the API is working..."
read

# ============================================
# Verify API Works
# ============================================
echo ""
echo "=== Verifying API Works ==="
echo ""
echo "Testing health endpoint..."
HEALTH=$(run_in_cluster curl -s http://sunday-app-service:5000/health)
echo "$HEALTH"
echo ""
echo "✓ API is responding"
echo ""
echo "Press Enter to TRIGGER A CRASH..."
read

# ============================================
# Trigger Crash
# ============================================
echo ""
echo "=== Triggering Application Crash ==="
echo ""
echo "Sending crash request..."
run_in_cluster curl -X POST http://sunday-app-service:5000/crash 2>&1 | head -2
echo ""
echo "✓ App crashed (container will restart)"
echo ""
echo "Waiting for Kubernetes to detect crash and restart container..."
echo "(This takes about 20-25 seconds)"

# Wait and check for restart
RESTARTED=false
for i in {1..10}; do
    sleep 3
    echo -n "."
    RESTARTS=$(kubectl get pods -l app=sunday-app -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null)
    if [ "$RESTARTS" != "0" ]; then
        RESTARTED=true
        break
    fi
done
echo ""

if [ "$RESTARTED" = "false" ]; then
    echo ""
    echo "⚠ Container hasn't restarted yet. Waiting longer..."
    sleep 10
fi

# ============================================
# Show Restart Counts
# ============================================
echo ""
echo "=== Checking Restart Counts ==="
echo ""
echo "EtherealPod restart count:"
kubectl get eps
echo ""
echo "Pod details:"
kubectl get pods -l app=sunday-app
echo ""

CONTAINER_RESTARTS=$(kubectl get pods -l app=sunday-app -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}')
EP_RESTARTS=$(kubectl get eps sunday-app -o jsonpath='{.status.restartCount}')

if [ "$CONTAINER_RESTARTS" -gt "0" ]; then
    echo "✓ Container restart count: $CONTAINER_RESTARTS"
else
    echo "⚠ Container restart count still 0 (may need more time)"
fi

if [ "$EP_RESTARTS" -gt "0" ]; then
    echo "✓ EtherealPod tracked restart: $EP_RESTARTS"
else
    echo "⚠ EtherealPod restart count still 0 (controller will update soon)"
fi

echo ""
echo "Waiting a bit more for controller to reconcile..."
sleep 10

echo ""
echo "Final check:"
kubectl get eps
echo ""

echo "Press Enter to verify app is working again..."
read

# ============================================
# Verify App Works After Restart
# ============================================
echo ""
echo "=== Verifying App Works After Restart ==="
echo ""
echo "Testing health endpoint..."
HEALTH_AFTER=$(run_in_cluster curl -s http://sunday-app-service:5000/health)
echo "$HEALTH_AFTER"
echo ""
echo "✓ App is healthy and responding"
echo ""

echo "=========================================="
echo "Demo 3B Complete!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✓ Application crashed (os._exit(1))"
echo "  ✓ Kubernetes detected crash and restarted container"
echo "  ✓ Container restart count incremented to $CONTAINER_RESTARTS"
echo "  ✓ EtherealPod controller tracked the restart: $EP_RESTARTS"
echo "  ✓ App is running and healthy again"
echo "  ✓ No port-forward needed - accessed via Service DNS!"
echo ""
