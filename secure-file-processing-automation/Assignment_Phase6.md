# Phase 6 – Move Files Based on Scan Result

## Objective

In this phase, the malware scanner is enhanced to automatically move scanned files to separate S3 buckets based on the scan result.

- Clean files are moved to the **Clean Bucket**
- Infected files are moved to the **Quarantine Bucket**

This ensures that the landing bucket only contains files waiting to be scanned, while scanned files are organized according to their status.

---

# Architecture

```text
                    +----------------------+
                    |  Landing Bucket      |
                    +----------+-----------+
                               |
                               |
                               ▼
                     S3 Event Notification
                               |
                               ▼
                          Amazon SQS
                               |
                               ▼
                     Python Malware Scanner
                               |
                +--------------+--------------+
                |                             |
                ▼                             ▼
        Scan Successful               Scan Infected
                |                             |
                ▼                             ▼
     Tag: scan-status=clean       Tag: scan-status=infected
                |                             |
                ▼                             ▼
      Move to Clean Bucket       Move to Quarantine Bucket
                |                             |
                +--------------+--------------+
                               |
                               ▼
                     Delete SQS Message
```

---

# S3 Buckets

Three buckets are used in this phase.

| Bucket | Purpose |
|---------|---------|
| file-scan-landing-dev | Receives uploaded files |
| file-scan-clean-dev | Stores clean files |
| file-scan-quarantine-dev | Stores infected files |

---

# Changes Made

## 1. Added New Environment Variables

The application now reads the destination buckets from environment variables instead of hardcoding bucket names.

### helper.py

```python
def get_clean_bucket():
    """Returns the clean bucket name."""

    print("Reading Clean Bucket Name...")

    return os.getenv("CLEAN_BUCKET")


def get_quarantine_bucket():
    """Returns the quarantine bucket name."""

    print("Reading Quarantine Bucket Name...")

    return os.getenv("QUARANTINE_BUCKET")
```

---

## 2. Added S3 Move Helper

A reusable helper function has been added to `aws_helper.py`.

```python
def move_s3_object(s3_client, source_bucket, destination_bucket, object_key):
    """Moves an S3 object from one bucket to another."""

    print(
        f"Moving '{object_key}' from '{source_bucket}' "
        f"to '{destination_bucket}'..."
    )

    copy_source = {
        "Bucket": source_bucket,
        "Key": object_key
    }

    s3_client.copy_object(
        Bucket=destination_bucket,
        Key=object_key,
        CopySource=copy_source
    )

    print("Object copied successfully.")

    s3_client.delete_object(
        Bucket=source_bucket,
        Key=object_key
    )

    print("Original object deleted successfully.")
```

### Explanation

Amazon S3 does not provide a native **Move Object** API.

A move operation is implemented as:

1. Copy the object to the destination bucket.
2. Delete the original object.

This helper encapsulates both operations into a single reusable function.

---

## 3. Updated Main Workflow

The application now reads the destination bucket names during startup.

```python
clean_bucket = get_clean_bucket()
quarantine_bucket = get_quarantine_bucket()
```

---

## 4. Determine Destination Bucket

After scanning the file, the destination bucket is selected based on the scan result.

```python
status = list(scan_result.values())[0][0]

if status == "OK":
    scan_status = "clean"
    destination_bucket = clean_bucket

    print(f"File '{object_key}' is clean.")

else:
    scan_status = "infected"
    destination_bucket = quarantine_bucket

    print(f"File '{object_key}' is infected.")
```

---

## 5. Move the File

After tagging the S3 object, the file is moved to the appropriate bucket.

```python
move_s3_object(
    s3_client,
    bucket_name,
    destination_bucket,
    object_key
)
```

---

## 6. Delete SQS Message

The SQS message is deleted only after:

- File downloaded successfully
- Scan completed successfully
- Object tagged successfully
- File moved successfully

```python
delete_message(
    sqs=sqs,
    queue_url=queue_url,
    receipt_handle=receipt_handle
)
```

This ensures failed operations are automatically retried by Amazon SQS.

---

# Docker Run Command

The container now requires two additional environment variables.

```bash
docker run --rm \
-e AWS_REGION=us-east-1 \
-e QUEUE_URL=https://sqs.us-east-1.amazonaws.com/023192525105/file-scan-queue-dev \
-e CLEAN_BUCKET=file-scan-clean-dev \
-e QUARANTINE_BUCKET=file-scan-quarantine-dev \
-v ~/.aws:/root/.aws \
-e AWS_PROFILE=dojo-dev-admin \
file-scanner:1.0
```

---

# Final Workflow

```text
Receive SQS Message
        │
        ▼
Download File
        │
        ▼
Scan using ClamAV
        │
        ▼
Determine Scan Status
        │
        ▼
Tag S3 Object
        │
        ▼
Move File
        │
        ├── Clean Bucket
        └── Quarantine Bucket
        │
        ▼
Delete Original Object
        │
        ▼
Delete SQS Message
```

---

# Testing

## Test 1 – Clean File

Upload a normal file.

Expected Result:

- File scanned successfully
- Object tagged

```
scan-status = clean
```

- Original object removed from:

```
file-scan-landing-dev
```

- File available in:

```
file-scan-clean-dev
```

- SQS message deleted

---

## Test 2 – Infected File

Upload the EICAR test file.

Expected Result:

- Malware detected
- Object tagged

```
scan-status = infected
```

- Original object removed from:

```
file-scan-landing-dev
```

- File available in:

```
file-scan-quarantine-dev
```

- SQS message deleted

---

# Summary

Phase 6 extends the malware scanning pipeline by automatically organizing scanned files into dedicated S3 buckets.

The application now:

- Downloads uploaded files from the landing bucket
- Scans files using ClamAV
- Tags each object with its scan status
- Moves clean files to the clean bucket
- Moves infected files to the quarantine bucket
- Removes the original object from the landing bucket
- Deletes the SQS message after successful processing

This keeps the landing bucket clean and ensures that scanned files are stored in the appropriate destination for further processing.