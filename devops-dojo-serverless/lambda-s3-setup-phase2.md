# Creating the Lambda Layer

## Why We Need a Lambda Layer

Before creating the Lambda function, the first task was to create a Lambda Layer.

Initially, we considered packaging the complete application along with all third-party Python libraries inside a single deployment ZIP.

```
lambda.zip
│
├── main.py
├── db.py
├── boto3
├── psycopg
├── psycopg_binary
├── typing_extensions
├── ...
```

Although this approach works, it has several disadvantages.

- The deployment ZIP becomes very large.
- Every small code change requires uploading all dependencies again.
- Multiple Lambda functions cannot share the same dependencies.
- Deployment becomes slower.

AWS recommends separating third-party libraries into Lambda Layers.

Therefore, we followed the production approach by creating a dedicated Lambda Layer for all external Python packages while keeping only our application code inside the deployment ZIP.

After separating the dependencies, our deployment package became much cleaner.

```
lambda.zip

main.py
db.py
```

All external libraries are now stored inside the Lambda Layer.

This makes future deployments much easier because only the application code changes while the dependencies remain unchanged.

---

# Choosing the Correct Runtime

Before creating the layer, we verified the Lambda runtime.

Our Lambda configuration uses:

```
Python 3.13
```

Architecture:

```
ARM64
```

This is an important decision because Lambda Layers are architecture-specific.

For example,

If the Lambda runtime is

```
Python 3.13 ARM64
```

then every dependency inside the Lambda Layer must also be compiled for

```
Python 3.13 ARM64 Linux
```

If we accidentally build the layer on macOS or x86 architecture, Lambda will fail with import errors.

During implementation we actually faced this issue.

Initially, the generated binaries were compiled for macOS which resulted in errors similar to

```
Unable to import module 'main'

No module named psycopg_binary

No pq wrapper available
```

The root cause was that the compiled libraries were not compatible with the Lambda execution environment.

To solve this problem, we decided to build the dependencies inside an AWS Lambda Docker image instead of using the local Python installation.

This guarantees that all libraries are compiled exactly as Lambda expects.

---

# Navigate to the Serverless Directory

All commands below are executed inside the serverless directory.

Navigate into the folder.

```bash
cd serverless
```

Verify the current directory.

```bash
pwd
```

Expected structure:

```
serverless/

main.py
db.py
requirements.txt
test.py
test_event.json
```

---

# Create the Layer Folder

AWS Lambda expects every Python Layer to contain a folder named

```
python
```

Therefore create the folder.

```bash
mkdir python
```

After creating it,

```
serverless/

python/
main.py
db.py
requirements.txt
```

Do not rename this folder.

AWS automatically searches for dependencies only inside a directory named

```
python
```

If another folder name is used, Lambda will not be able to import the libraries.

---

# Why Docker Was Used

Initially, we tried installing the dependencies directly on the local machine.

Example:

```bash
pip install -r requirements.txt -t python
```

Although the installation completed successfully, the generated shared libraries were built for macOS.

AWS Lambda runs on Amazon Linux.

Because of this mismatch, Lambda was unable to load the psycopg binary.

Instead of trying to manually install Linux libraries, we used Docker.

Docker allows us to create the dependencies inside the exact same operating system used by AWS Lambda.

This eliminates compatibility issues.

---

# Download the Official Lambda Image

The official AWS Lambda Python image was used.

```
public.ecr.aws/lambda/python:3.13
```

If the image is not available locally, Docker automatically downloads it.

---

# Install Dependencies inside Docker

Run the following command from the serverless directory.

```bash
docker run --rm \
--platform linux/arm64 \
-v "$PWD/python:/var/task/python" \
public.ecr.aws/lambda/python:3.13 \
/bin/sh -c "pip install psycopg[binary] boto3 -t /var/task/python"
```

Let's understand this command.

### docker run

Starts a temporary container.

---

### --rm

Automatically deletes the container after execution.

No unnecessary containers remain on the machine.

---

### --platform linux/arm64

This is one of the most important options.

Our Lambda function is configured for

```
ARM64
```

Therefore the dependencies must also be compiled for ARM64.

If x86 libraries are generated, Lambda cannot load them.

---

### -v "$PWD/python:/var/task/python"

Maps the local

```
python
```

folder into the Docker container.

Any dependency installed inside

```
/var/task/python
```

will automatically appear inside the local

```
python
```

directory.

---

### public.ecr.aws/lambda/python:3.13

Official AWS Lambda Docker image.

This image contains the exact runtime used by Lambda.

---

### pip install

Installs all required dependencies.

The command installs

- psycopg
- psycopg_binary
- boto3

inside the python directory.

---

# Verify the Layer

After installation completes,

open the python directory.

You should see folders similar to

```
python/

psycopg/
psycopg_binary/
typing_extensions/
```

One important verification step is checking the shared library.

Navigate to

```
python/
└── psycopg_binary/
```

You should find files similar to

```
pq.cpython-313-aarch64-linux-gnu.so

_psycopg.cpython-313-aarch64-linux-gnu.so
```

Notice

```
313
```

indicates Python 3.13

and

```
aarch64
```

indicates ARM64 Linux.

This confirms the layer has been built correctly.

If instead you see files containing

```
darwin

macos

x86_64
```

the layer is incorrect and Lambda will fail.

---

# Package the Layer

Once the python directory has been verified,

create the layer ZIP.

Run

```bash
zip -r layer.zip python
```

This creates

```
layer.zip
```

The ZIP structure should look like

```
layer.zip

python/
    psycopg/
    psycopg_binary/
    boto3/
```

The ZIP should NOT contain

```
main.py
db.py
```

Only dependencies belong inside the Layer.

---

# Upload the Layer

Navigate to

```
AWS Console

↓

Lambda

↓

Layers

↓

Create Layer
```

Provide

Layer Name

```
dojo-dev-layer
```

Upload

```
layer.zip
```

Compatible Runtime

```
Python 3.13
```

Compatible Architecture

```
ARM64
```

Click

```
Create
```

After creation,

open your Lambda function.

Navigate

```
Lambda

↓

dojo-dev-upload-processor

↓

Layers

↓

Add Layer

↓

Custom Layers

↓

Select dojo-dev-layer

↓

Add
```

The Lambda now has access to every dependency inside the Layer without bundling them inside the deployment ZIP.

At this point, the dependency management for the Lambda function is complete.

The next step is creating the deployment package containing only the application source code and configuring the Lambda function itself.