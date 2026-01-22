from flask import Flask, request, jsonify
from app.db import init_db, get_db_session
from app.models import GroceryEntry
from sqlalchemy import func

app = Flask(__name__)

# Create tables on startup
init_db()

# Test restart functionality: uncomment the line below to make app crash on startup
# This will cause Kubernetes to restart the container, incrementing restart count
# import os; os._exit(1): Will be disabled after test

@app.route('/get_product_amount', methods=['GET'])
def get_product_amount():
    product_name = request.args.get('product_name', '').lower()
    if not product_name:
        return {"error": "product_name parameter required"}, 400

    db = get_db_session()
    try:
        total = db.query(func.sum(GroceryEntry.amount)).filter(
            GroceryEntry.product_name == product_name
        ).scalar() or 0
        
        return jsonify({'amount': int(total)})
    finally:
        db.close()

@app.route('/write', methods=['POST'])
def write():
    data = request.get_json()
    if not data:
        return {"error": "Invalid request data"}, 400

    user_id = data.get('user_id', '').lower()
    product_name = data.get('product_name', '').lower()
    amount = data.get('amount')
    
    if not user_id:
        return {"error": "user_id is required"}, 400
    if not product_name:
        return {"error": "product_name is required"}, 400
    if amount is None:
        return {"error": "amount is required"}, 400
    if amount <= 0:
        return {"error": "amount must be greater than 0"}, 400

    db = get_db_session()
    try:
        # Query for existing entry (composite key lookup)
        entry = db.query(GroceryEntry).filter(
            GroceryEntry.user_id == user_id,
            GroceryEntry.product_name == product_name
        ).first()
        
        if entry:
            entry.amount += amount
        else:
            entry = GroceryEntry(user_id=user_id, product_name=product_name, amount=amount)
            db.add(entry)
        
        db.commit()
        
        return jsonify({
            "user_id": entry.user_id,
            "product_name": entry.product_name,
            "amount": entry.amount
        }), 200
    except Exception as e:
        db.rollback()
        return {"error": str(e)}, 500
    finally:
        db.close()

@app.route("/delete_product", methods=["DELETE"])
def delete_product():
    product_name = request.args.get("product_name", "").lower()
    
    if not product_name:
        return jsonify({"error": "product_name parameter required"}), 400

    db = get_db_session()
    try:
        deleted = db.query(GroceryEntry).filter(
            GroceryEntry.product_name == product_name
        ).delete()
        
        db.commit()
        
        return jsonify({
            "product_name": product_name,
            "deleted_rows": deleted
        }), 200
    except Exception as e:
        db.rollback()
        return {"error": str(e)}, 500
    finally:
        db.close()

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy'}), 200

@app.route('/crash', methods=['POST'])
def crash():
    """Test endpoint to crash the app and trigger restart"""
    import os
    os._exit(1) 

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)