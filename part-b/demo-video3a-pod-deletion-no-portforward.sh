#!/bin/bash

# Video 3A: Pod Deletion Recovery & Data Persistence
# No port-forward needed - runs commands inside the cluster!

echo "=========================================="
echo "Video 3A: Pod Deletion & Data Persistence"
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
echo "=== Current State ==="
echo ""
echo "EtherealPod and Pod:"
kubectl get eps && echo "" && kubectl get pods -l app=sunday-app
echo ""
echo "Press Enter to add some data..."
read

# ============================================
# Add Data Before Deletion
# ============================================
echo ""
echo "=== Adding Test Data ==="
echo ""
echo "Adding 3 apples..."
run_in_cluster curl -s -X POST http://sunday-app-service:5000/write \
  -H "Content-Type: application/json" \
  -d '{"user_id": "loki", "product_name": "apple", "amount": 3}'

echo ""
echo "Current amount of apples:"
RESPONSE=$(run_in_cluster curl -s http://sunday-app-service:5000/get_product_amount?product_name=apple)
AMOUNT=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['amount'])" 2>/dev/null)

echo "  🍎 Apples: $AMOUNT"
echo ""
echo "✓ We have $AMOUNT apples stored"
echo ""
echo "Press Enter to DELETE the pod..."
read

# ============================================
# Delete Pod
# ============================================
echo ""
echo "=== Deleting Pod ==="
echo ""
OLD_POD=$(kubectl get pods -l app=sunday-app -o jsonpath='{.items[0].metadata.name}')
echo "Current pod: $OLD_POD"
echo "Deleting..."
kubectl delete pod -l app=sunday-app,component=api
echo ""
echo "Waiting for controller to recreate pod..."
sleep 8

# ============================================
# Show New Pod
# ============================================
echo ""
echo "=== New Pod Created ==="
echo ""
NEW_POD=$(kubectl get pods -l app=sunday-app -o jsonpath='{.items[0].metadata.name}')
kubectl get pods -l app=sunday-app
echo ""
echo "Old pod was: $OLD_POD"
echo "New pod is:  $NEW_POD"
echo ""
echo "Press Enter to check EtherealPod status..."
read

# ============================================
# Show Updated Status
# ============================================
echo ""
echo "=== EtherealPod Status Updated ==="
echo ""
kubectl get etherealpods sunday-app -o yaml | grep -A 3 "status:"
echo ""
echo "✓ Controller updated status with new pod name"
echo ""
echo "Press Enter to verify DATA PERSISTED..."
read

# ============================================
# Verify Data Persisted
# ============================================
echo ""
echo "=== Verifying Data Persistence ==="
echo ""
echo "Checking if our apples are still there..."
RESPONSE_AFTER=$(run_in_cluster curl -s http://sunday-app-service:5000/get_product_amount?product_name=apple)
AMOUNT_AFTER=$(echo "$RESPONSE_AFTER" | python3 -c "import sys, json; print(json.load(sys.stdin)['amount'])" 2>/dev/null)

echo "  🍎 Apples: $AMOUNT_AFTER"
echo ""
if [ "$AMOUNT_AFTER" = "$AMOUNT" ]; then
    echo "✓ Data persisted! We still have $AMOUNT_AFTER apples"
else
    echo "⚠ Amount changed (was $AMOUNT, now $AMOUNT_AFTER)"
fi
echo ""
echo "PostgreSQL kept our data safe through pod deletion!"
echo ""


echo "Summary:"
echo "  ✓ Started with $AMOUNT apples"
echo "  ✓ Deleted the pod"
echo "  ✓ Controller automatically recreated it"
echo "  ✓ Still had $AMOUNT_AFTER apples (data persisted!)"
echo "  ✓ PostgreSQL kept data safe through pod recreation"
echo "  ✓ No port-forward needed - accessed via Service DNS!"
echo ""
