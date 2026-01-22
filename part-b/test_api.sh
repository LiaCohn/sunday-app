#!/bin/bash

BASE_URL="http://localhost:5000"

# Optional: check jq exists (for nicer output)
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is not installed. Please install jq to run this demo."
  exit 1
fi

echo "=============================="
echo "1. Health check"
echo "=============================="
curl -s $BASE_URL/health | jq .

echo -e "\n=============================="
echo "2. Adding products"
echo "=============================="

echo "- Add 1 apple for user loki"
curl -s -X POST $BASE_URL/write \
  -H "Content-Type: application/json" \
  -d '{"user_id": "loki", "product_name": "apple", "amount": 1}' | jq .

echo "- Add 3 beers for user thor"
curl -s -X POST $BASE_URL/write \
  -H "Content-Type: application/json" \
  -d '{"user_id": "thor", "product_name": "beer", "amount": 3}' | jq .

echo -e "\n=============================="
echo "3. Get product amounts"
echo "=============================="

echo "- Get total apples"
curl -s "$BASE_URL/get_product_amount?product_name=apple" | jq .

echo "- Get total beer"
curl -s "$BASE_URL/get_product_amount?product_name=beer" | jq .

echo -e "\n=============================="
echo "4. Update existing product (accumulation)"
echo "=============================="

echo "- Add 2 more apples for user loki"
curl -s -X POST $BASE_URL/write \
  -H "Content-Type: application/json" \
  -d '{"user_id": "loki", "product_name": "apple", "amount": 2}' | jq .

echo "- Verify updated apple amount"
curl -s "$BASE_URL/get_product_amount?product_name=apple" | jq .

echo -e "\n=============================="
echo "5. Delete product"
echo "=============================="

echo "- Delete all beer entries"
curl -s -X DELETE "$BASE_URL/delete_product?product_name=beer" | jq .

echo "- Verify beer was deleted"
curl -s "$BASE_URL/get_product_amount?product_name=beer" | jq .

echo -e "\n=============================="
echo "6. Edge cases"
echo "=============================="

echo "- Get amount for non-existing product (milk)"
curl -s "$BASE_URL/get_product_amount?product_name=milk" | jq .

echo "- Delete non-existing product (milk)"
curl -s -X DELETE "$BASE_URL/delete_product?product_name=milk" | jq .

echo -e "\n=============================="
echo "Demo finished successfully"
echo "=============================="
