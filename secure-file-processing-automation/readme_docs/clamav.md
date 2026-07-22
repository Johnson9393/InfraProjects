# ClamAV - Installation, Testing & Python Automation Guide

# What is ClamAV?

ClamAV (Clam AntiVirus) is an open-source antivirus engine used to detect malware, viruses, trojans, malicious scripts, and infected files.

It is widely used in:

- Linux Servers
- Docker Containers
- Email Gateways
- File Upload Systems
- Cloud Applications
- DevSecOps Pipelines
- Python Automation Scripts

Unlike traditional antivirus software, ClamAV is primarily designed for servers and automation rather than providing real-time desktop protection.

---

# Why ClamAV?

Whenever a user uploads a file to your application, it is considered a security best practice to scan the file before processing or storing it.

Example:

```
User Uploads File
        │
        ▼
Virus Scan (ClamAV)
        │
 ┌──────┴────────┐
 │               │
 ▼               ▼
Clean File    Infected File
 │               │
 ▼               ▼
Process      Reject / Quarantine
```

---

# Installation

## Check Homebrew

```bash
brew --version
```

---

## Install ClamAV

```bash
brew install clamav
```

---

## Verify Installation

```bash
clamscan --version
```

Expected Output

```
ClamAV 1.x.x
```

---

# Configure ClamAV

Copy sample configuration

```bash
cp /opt/homebrew/etc/clamav/freshclam.conf.sample \
/opt/homebrew/etc/clamav/freshclam.conf
```

Remove the Example line

```bash
sed -i '' '/^Example/d' \
/opt/homebrew/etc/clamav/freshclam.conf
```

---

# Download Latest Virus Definitions

```bash
freshclam
```

This downloads the latest virus signature database.

---

# Testing ClamAV

Create a test directory

```bash
mkdir ~/clamav-test

cd ~/clamav-test
```

---

## Create EICAR Test File

```bash
cat > eicar.com << 'EOF'
X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*
EOF
```

> The EICAR file is NOT a real virus.
> It is an industry-standard antivirus test file used to validate antivirus software.

---

## Scan Single File

```bash
clamscan eicar.com
```

Expected Output

```
eicar.com: Eicar-Test-Signature FOUND
```

---

## Scan Entire Directory

```bash
clamscan -r ~/clamav-test
```

---

# Useful Commands

Update virus definitions

```bash
freshclam
```

Scan recursively

```bash
clamscan -r .
```

Move infected files

```bash
mkdir quarantine

clamscan -r --move=quarantine .
```

Delete infected files

```bash
clamscan -r --remove .
```

---

# Cleanup

Delete test file

```bash
rm ~/clamav-test/eicar.com
```

Delete test folder

```bash
rm -rf ~/clamav-test
```

---

# Python Automation Use Case

One of the most common automation use cases is scanning uploaded files before processing them.

Workflow

```
User Uploads CSV

        │

        ▼

Python Automation

        │

        ▼

Run ClamAV Scan

        │

 ┌──────┴─────────┐

 │                │

 ▼                ▼

Clean          Infected

 │                │

 ▼                ▼

Continue      Reject Upload
Processing
```

---

# Example Python Automation

```python
import subprocess

result = subprocess.run(
    ["clamscan", "sample.csv"],
    capture_output=True,
    text=True
)

print(result.stdout)

if "FOUND" in result.stdout:
    print("Virus detected")
else:
    print("File is clean")
```

---

# Example DevOps Use Case

Suppose users upload CSV files to your application.

Instead of directly processing them,

the application first scans the uploaded file.

```
React UI

      │

      ▼

Flask Backend

      │

      ▼

Upload CSV

      │

      ▼

Python Automation

      │

      ▼

ClamAV Scan

      │

 ┌────┴─────┐

 │          │

 ▼          ▼

Clean     Virus

 │          │

 ▼          ▼

Store     Reject
to S3
```

This prevents malicious files from entering the application.

---

# AWS Cloud Example

```
User Upload

      │

      ▼

Amazon S3

      │

      ▼

Lambda

      │

      ▼

Download File

      │

      ▼

Run ClamAV Scan

      │

 ┌────┴────┐

 │         │

 ▼         ▼

Clean    Infected

 │         │

 ▼         ▼

Process   Move to
CSV       Quarantine Bucket
```

This architecture is commonly used in enterprise cloud applications.

---

# DevOps Benefits

- Automated malware detection
- Secure file upload pipeline
- Prevents malicious files entering the system
- Easily integrates with Python scripts
- Works inside Docker containers
- Can be integrated with CI/CD pipelines
- Suitable for Lambda, ECS, EC2 and Kubernetes workloads

---

# Key Learnings

- Learned how to install ClamAV using Homebrew.
- Updated virus signature database using `freshclam`.
- Tested antivirus functionality using the EICAR test file.
- Performed recursive directory scanning.
- Understood how Python can execute ClamAV using the `subprocess` module.
- Learned how ClamAV fits into secure file upload workflows.
- Understood how ClamAV can be integrated into AWS architectures for automated malware scanning.

---

