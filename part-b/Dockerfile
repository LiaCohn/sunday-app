# Use an official Python image as a base
FROM python:3.12-slim

# Set working directory inside the container
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the app code
COPY . .

# Create directory for database
RUN mkdir -p /data && chmod 777 /data

# Expose the port your Flask app runs on
EXPOSE 5000

# Set environment variable for database location
ENV DATABASE_URL=sqlite:///data/groceries.db

# Run Flask when container starts (use python app.py instead of flask run)
CMD ["python", "app.py"]