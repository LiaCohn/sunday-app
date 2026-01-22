from sqlalchemy import Column, String, Integer, CheckConstraint
from sqlalchemy.orm import declarative_base

Base = declarative_base()

class GroceryEntry(Base):
    __tablename__ = "groceries"

    user_id = Column(String, primary_key=True)
    product_name = Column(String, primary_key=True)
    amount = Column(Integer, nullable=False)

    __table_args__ = (
        CheckConstraint('amount > 0', name='check_amount_positive'),
    )
