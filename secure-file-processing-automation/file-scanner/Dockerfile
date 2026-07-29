# Base Python image
FROM python:3.13-slim

# Install ClamAV packages
# updating ap-get firstly cuz the base image is slim and may not have the latest package lists.
# rm -rf /var/lib/apt/lists/* is used to clean up the apt cache and reduce the size of the Docker image.
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
#no-cache-dir flag is used to prevent caching of the installed packages, which helps reduce the size of the Docker image.
RUN pip install --no-cache-dir -r requirements.txt 

# Copy application source code
# copy . . will again copies all the files including requirements.txt but since we have already installed the dependencies, it won't reinstall them. This is a common practice to optimize Docker builds by separating the installation of dependencies from the copying of application code. which helps in layer caching.
COPY . .

# Make entrypoint executable
RUN chmod +x entrypoint.sh

# Start the application
ENTRYPOINT ["./entrypoint.sh"]