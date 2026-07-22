# Creating the Lambda Deployment Package

After successfully creating the Lambda Layer, the next step was to create the Lambda deployment package.

Since all third-party dependencies are already available inside the Layer, the deployment package only needs to contain our application code.

This significantly reduces the deployment size and makes future deployments much easier.

The deployment ZIP contains only the following files.

```

lambda.zip

main.py
db.py

```

No external Python libraries should be included inside this ZIP because Lambda will automatically load them from the attached Layer.

---

# Creating lambda.zip

Navigate to the serverless directory.

```bash
cd serverless
```

Verify the files.

```bash
ls
```

Expected output

```
main.py
db.py
requirements.txt
python/
test.py
test_event.json
```

Create the deployment ZIP.

```bash
zip lambda.zip main.py db.py
```

After successful execution,

```
serverless/

lambda.zip
main.py
db.py
requirements.txt
python/
```

The deployment package is now ready.

---

# Why Does lambda.zip Contain Only Two Files?

Initially, we considered uploading everything.

```
main.py
db.py
psycopg
boto3
typing_extensions
...
```

But since these dependencies already exist inside the Lambda Layer, uploading them again would be unnecessary.

Advantages of this approach

- Smaller deployment package.
- Faster uploads.
- Cleaner deployment.
- Dependencies managed independently.
- Easier maintenance.

This is the recommended production approach.

---

# Creating the Lambda Function

Navigate to

```
AWS Console

↓

Lambda

↓

Create Function
```

Choose

```
Author from Scratch
```

Provide

Function Name

```
dojo-dev-upload-processor
```

Runtime

```
Python 3.13
```

Architecture

```
ARM64
```

Permissions

Choose

```
Use Existing Role
```

Select the execution role that was created earlier.

Click

```
Create Function
```

The Lambda function is now created.

---

# Upload the Deployment Package

Navigate to

```
Lambda

↓

dojo-dev-upload-processor

↓

Code
```

Click

```
Upload From

↓

.zip File
```

Select

```
lambda.zip
```

Click

```
Save
```

At this stage,

the Lambda contains only

```
main.py
db.py
```

All external dependencies are loaded from the Layer.

---

# Understanding db.py

Originally, our database connection looked like this.

```python
DATABASE_URL = (
    f"postgresql://{os.environ['DB_USER']}:"
    f"{os.environ['DB_PASSWORD']}@"
    f"{os.environ['DB_HOST']}:"
    f"{os.environ.get('DB_PORT', '5432')}/"
    f"{os.environ['DB_NAME']}"
)
```

This means Lambda required multiple environment variables.

```
DB_HOST

DB_NAME

DB_USER

DB_PASSWORD

DB_PORT
```

Although functional,

this approach has several disadvantages.

- Database password stored inside Lambda.
- Password visible to users having Lambda access.
- Difficult credential rotation.
- Multiple environment variables to manage.
- Not considered a production best practice.

We therefore decided to replace this implementation with AWS Secrets Manager.

---

# New Database Connection Approach

Instead of storing every credential inside Lambda,

only a single environment variable is stored.

```
SECRET_NAME
```

The database credentials remain securely stored inside AWS Secrets Manager.

The updated implementation inside db.py becomes

```python
import boto3
import os
import psycopg

SECRET_NAME = os.environ["SECRET_NAME"]

client = boto3.client("secretsmanager")

def get_db_connection():

    response = client.get_secret_value(
        SecretId=SECRET_NAME
    )

    database_url = response["SecretString"]

    return psycopg.connect(database_url)
```

---

# Why This Approach Is Better

The application no longer knows

```
Database Host

Database Username

Database Password

Database Name
```

Instead,

Lambda only knows

```
dojo-dev-rds-secrets
```

During execution,

the flow becomes

```
Lambda Starts

↓

Read Environment Variable

↓

SECRET_NAME

↓

Call AWS Secrets Manager

↓

Retrieve PostgreSQL Connection String

↓

Create Database Connection
```

Advantages

- Credentials never stored inside Lambda.
- Password rotation becomes easy.
- Better security.
- Production standard.
- IAM controls access to the secret.

---

# Creating the Secret

The PostgreSQL connection string was already available inside AWS Secrets Manager.

Secret Name

```
dojo-dev-rds-secrets
```

The stored value is a PostgreSQL connection string similar to

```
postgresql://username:password@hostname:5432/database
```

Since the connection string already contains

- Username
- Password
- Host
- Port
- Database

there is no need to construct it manually.

Lambda simply retrieves the secret and passes it directly into

```
psycopg.connect()
```

making the implementation much simpler.

---

# Configure Runtime Settings

Navigate

```
Lambda

↓

dojo-dev-upload-processor

↓

Configuration

↓

Runtime Settings
```

Initially,

the handler was incorrect.

Because of this,

Lambda failed immediately with an import error.

The handler was updated to

```
main.lambda_handler
```

This tells Lambda

```
File Name

↓

main.py

↓

Function

↓

lambda_handler()
```

Every Lambda invocation begins by calling

```
lambda_handler()
```

inside

```
main.py
```

Always verify this setting after uploading the code.

A wrong handler is one of the most common reasons for Lambda failures.

---

# Configure Memory

Navigate

```
Configuration

↓

General Configuration
```

Memory

```
512 MB
```

Timeout

```
1 Minute
```

Although our current CSV files are small,

512 MB provides sufficient memory for

- Reading files
- Processing CSV
- Database connectivity

while keeping execution costs low.

---

# Attach the Lambda Layer

Navigate

```
Lambda

↓

Layers

↓

Add Layer

↓

Custom Layers
```

Choose

```
dojo-dev-layer
```

Click

```
Add
```

Without attaching this Layer,

Lambda cannot import

```
psycopg

psycopg_binary
```

and execution fails immediately.

Always verify that the Layer appears under

```
Layers
```

before testing the Lambda.
