# Base image — slim keeps it small
FROM python:3.11-slim

# Set working directory inside the container
WORKDIR /app

# Copy dependencies file first (layer caching — explained below)
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY . .

# Tell Docker this container listens on port 5000
EXPOSE 5000

# Command to run when container starts
CMD ["python", "app.py"]
