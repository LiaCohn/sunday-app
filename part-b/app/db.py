from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, scoped_session
from app.models import Base
import os
import sys

# PostgreSQL connection string format: postgresql://user:password@host:port/database
DATABASE_URL = os.getenv(
    "DATABASE_URL", 
    "postgresql://sundayuser:sundaypass@postgres-service:5432/sundaydb"
)

# Create engine for PostgreSQL
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,  # Verify connections before using
    pool_size=5,
    max_overflow=10,
    echo=False,
)

SessionLocal = scoped_session(sessionmaker(autocommit=False, autoflush=False, bind=engine))

def init_db():
    """Initialize database - create tables"""
    try:
        Base.metadata.create_all(bind=engine)
        print("✓ Database tables created successfully", file=sys.stderr, flush=True)
    except Exception as e:
        print(f"✗ Error creating database tables: {e}", file=sys.stderr, flush=True)
        raise

def get_db_session():
    return SessionLocal()
