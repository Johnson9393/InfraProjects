# db-tunnel.sh - Detailed Walkthrough

This document explains every section of the `db-tunnel.sh` script.

---

# 1. Safe Execution

```bash
set -euo pipefail
```

### What this does

This enables strict error handling.

- `-e` → Stop immediately if any command fails.
- `-u` → Throw an error if an undefined variable is used.
- `pipefail` → If any command in a pipeline fails, the entire pipeline fails.

This prevents the script from continuing in an invalid state.

---

# 2. Terminal Colors

```bash
COLOR_DEFAULT='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_RED='\033[0;31m'
```

### What this does

Defines ANSI color codes for printing colored messages.

Example:

- Green → Success
- Blue → Information
- Yellow → Progress
- Red → Errors

---

# 3. Usage Function

```bash
usage() {
    echo ""
    echo "Usage:"
    echo "bash scripts/db-tunnel.sh -e <environment> -p <local_port>"
    echo ""
    echo "Example:"
    echo "bash scripts/db-tunnel.sh -e dev -p 65001"
    exit 1
}
```

### What this does

Displays the correct command syntax when the required arguments are missing or invalid.

Expected command:

```bash
bash scripts/db-tunnel.sh -e dev -p 65001
```

---

# 4. Default Variables

```bash
environment=""
local_port=65001
```

### What this does

Initializes variables before reading command-line arguments.

- `environment` stores the deployment environment.
- `local_port` is the local port used for the database tunnel.

---

# 5. Read Command-Line Arguments

```bash
while getopts "e:p:" option
do
    case "$option" in
        e) environment=$OPTARG ;;
        p) local_port=$OPTARG ;;
        *) usage ;;
    esac
done
```

### What this does

Reads arguments passed to the script.

Supported options:

- `-e` → Environment (`dev`, `prod`, etc.)
- `-p` → Local port

Example:

```bash
bash scripts/db-tunnel.sh -e dev -p 65001
```

After execution:

```text
environment = dev
local_port = 65001
```

---

# 6. Validate Environment

```bash
[[ -z "$environment" ]] && usage
```

### What this does

Checks whether the user supplied the environment.

If not, the script displays the usage message and exits.

---

# 7. Validate AWS Profile

```bash
if [[ -z "${AWS_PROFILE:-}" ]]; then
    echo "AWS_PROFILE is not exported."
    exit 1
fi
```

### What this does

Checks whether an AWS profile has already been exported.

Expected:

```bash
export AWS_PROFILE=AdministratorAccess-<>
```

The script assumes you've already completed:

```bash
aws sso login --profile AdministratorAccess-<>
```

---

# 8. Find the Bastion EC2

```bash
instance_id=$(aws ec2 describe-instances ...)
```

### What this does

Uses the AWS CLI to search for a **running** Bastion EC2 based on its tags.

It retrieves:

- Instance ID

No instance ID is hardcoded.

---

# 9. Find the RDS Endpoint

```bash
db_endpoint=$(aws rds describe-db-instances ...)
```

### What this does

Queries AWS RDS and retrieves the endpoint of the database associated with the selected environment.

No endpoint is hardcoded.

---

# 10. Start the SSM Tunnel

```bash
aws ssm start-session \
    --target ${instance_id} \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters ...
```

### What this does

Creates an encrypted port-forwarding session using AWS Systems Manager.

Traffic flows like this:

```
Laptop
   │
localhost:65001
   │
AWS Systems Manager
   │
Bastion EC2
   │
Private RDS:5432
```

The tunnel remains active until you press **Ctrl + C**.

---

# Daily Workflow

```bash
aws sso login --profile AdministratorAccess-<>

export AWS_PROFILE=AdministratorAccess-<>

bash scripts/db-tunnel.sh -e dev -p 65001
```

Open DBeaver:

```
Host      : localhost
Port      : 65001
Database  : <database_name>
Username  : <db_username>
Password  : <db_password>
```