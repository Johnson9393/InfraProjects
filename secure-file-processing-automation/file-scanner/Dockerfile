# Base Python image
FROM python:3.13-slim

# Install ClamAV packages
RUN apt-get update && \
    apt-get install -y \
        clamav \
        clamav-daemon && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Copy dependency file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY . .

# Make entrypoint executable
RUN chmod +x entrypoint.sh

# Start the application
ENTRYPOINT ["./entrypoint.sh"]