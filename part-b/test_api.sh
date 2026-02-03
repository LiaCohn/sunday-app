#!/bin/bash

# This script tests the API from INSIDE the Kubernetes cluster
# No port-forward needed!

BASE_URL="http://sunday-app-service:5000"

# Check if jq exists
if ! command -v jq >/dev/null 2>&1; then
  echo "⚠️  jq is not installed. Install with: brew install jq"
  exit 1
fi

# Helper function to run curl inside cluster
run_curl() {
    kubectl run curl-test --image=curlimages/curl:latest --rm -i --restart=Never --quiet -- "$@" 2>/dev/null
}

echo "🧪 Testing Sunday App API..."
echo ""

# Check if app pod is running
APP_POD=$(kubectl get pods -l app=sunday-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$APP_POD" ]; then
    echo "❌ No app pod found. Make sure the app is deployed."
    exit 1
fi
echo "✅ Pod is running: $APP_POD"
echo ""

echo "Testing basic operations..."
echo ""

echo "=============================="
echo "1. Health check"
echo "=============================="
run_curl curl -s $BASE_URL/health | jq .

echo -e "\n=============================="
echo "2. Adding products"
echo "=============================="

echo "- Add 1 apple for user loki"
run_curl curl -s -X POST $BASE_URL/write \
  -H "Content-Type: application/json" \
  -d '{"user_id": "loki", "product_name": "apple", "amount": 1}' | jq .

echo "- Add 3 beers for user thor"
run_curl curl -s -X POST $BASE_URL/write \
  -H "Content-Type: application/json" \
  -d '{"user_id": "thor", "product_name": "beer", "amount": 3}' | jq .

echo -e "\n=============================="
echo "3. Get product amounts"
echo "=============================="

echo "- Get total apples"
run_curl curl -s "$BASE_URL/get_product_amount?product_name=apple" | jq .

echo "- Get total beer"
run_curl curl -s "$BASE_URL/get_product_amount?product_name=beer" | jq .

echo -e "\n=============================="
echo "4. Update existing product (accumulation)"
echo "=============================="

echo "- Add 2 more apples for user loki"
run_curl curl -s -X POST $BASE_URL/write \
  -H "Content-Type: application/json" \
  -d '{"user_id": "loki", "product_name": "apple", "amount": 2}' | jq .

echo "- Verify updated apple amount"
run_curl curl -s "$BASE_URL/get_product_amount?product_name=apple" | jq .

echo -e "\n=============================="
echo "5. Delete product"
echo "=============================="

echo "- Delete all beer entries"
run_curl curl -s -X DELETE "$BASE_URL/delete_product?product_name=beer" | jq .

echo "- Verify beer was deleted"
run_curl curl -s "$BASE_URL/get_product_amount?product_name=beer" | jq .

echo -e "\n=============================="
echo "6. Edge cases"
echo "=============================="

echo "- Get amount for non-existing product (milk)"
run_curl curl -s "$BASE_URL/get_product_amount?product_name=milk" | jq .

echo "- Delete non-existing product (milk)"
run_curl curl -s -X DELETE "$BASE_URL/delete_product?product_name=milk" | jq .

echo -e "\n=============================="
echo "✅ Demo finished successfully"
echo "=============================="