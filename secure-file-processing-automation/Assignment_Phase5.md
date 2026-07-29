# Phase 5 – S3 Object Tagging

## Objective

In this phase, the malware scanner is enhanced to update the scanned S3 object with a tag indicating whether the file is **clean** or **infected**.

This helps downstream applications determine the scan status without re-scanning the file.

---

# Flow

```text
S3 Upload
    │
    ▼
S3 Event Notification
    │
    ▼
Amazon SQS
    │
    ▼
Python Worker
    │
    ├── Download File
    ├── Scan using ClamAV
    ├── Tag S3 Object
    └── Delete SQS Message
```

---

# Changes Made

## 1. Added S3 Object Tagging Helper

A new helper function has been added to `aws_helper.py`.

```python
def tag_s3_object(s3_client, bucket_name, object_key, scan_status):
    """Adds a scan status tag to an S3 object."""

    print(f"Tagging S3 object as '{scan_status}'...")

    s3_client.put_object_tagging(
        Bucket=bucket_name,
        Key=object_key,
        Tagging={
            "TagSet": [
                {
                    "Key": "scan-status",
                    "Value": scan_status
                }
            ]
        }
    )

    print("S3 object tagged successfully.")
```

### Explanation

This helper uses the AWS S3 `put_object_tagging()` API to update the object tags.

Two possible values are used:

| Tag Key | Tag Value |
|---------|-----------|
| scan-status | clean |
| scan-status | infected |

---

## 2. Updated Main Workflow

After downloading the file from S3, the application now stores the ClamAV scan result.

```python
scan_result = scan_file(local_file_path)
```

---

## 3. Determine Scan Status

The ClamAV Python library returns:

### Clean File

```python
{
    "/tmp/scanner/file.txt": ("OK", None)
}
```

### Infected File

```python
{
    "/tmp/scanner/eicar.txt": ("FOUND", "Eicar-Signature")
}
```

Instead of checking whether the result is `None`, the application now checks the scan status.

```python
status = list(scan_result.values())[0][0]

if status == "OK":
    scan_status = "clean"
    print(f"File '{object_key}' is clean.")
else:
    scan_status = "infected"
    print(f"File '{object_key}' is infected.")
```

---

## 4. Tag the S3 Object

After determining the scan status, the application updates the object tags.

```python
tag_s3_object(
    s3,
    bucket_name,
    object_key,
    scan_status
)
```

---

## 5. Delete the SQS Message

The SQS message is deleted only after:

- File downloaded successfully
- Scan completed successfully
- Object tagged successfully

```python
delete_message(
    sqs=sqs,
    queue_url=queue_url,
    receipt_handle=receipt_handle
)
```

This ensures failed scans or tagging operations can be retried automatically by Amazon SQS.

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
Delete SQS Message
```

---

# Testing

## Test 1 – Clean File

Upload a clean file.

Expected result:

- File downloaded successfully
- ClamAV returns `OK`
- Object tagged with:

```
scan-status = clean
```

Example log:

```text
Scanning file: docker_questions.csv
Scan Result: {'/tmp/scanner/docker_questions.csv': ('OK', None)}
File 'docker_questions.csv' is clean.
Tagging S3 object as 'clean'...
S3 object tagged successfully.
```

---

## Test 2 – Infected File

Upload the EICAR test file.

Expected result:

- File downloaded successfully
- ClamAV detects malware
- Object tagged with:

```
scan-status = infected
```

Example log:

```text
Scanning file: eicar.txt
Scan Result: {'/tmp/scanner/eicar.txt': ('FOUND', 'Eicar-Signature')}
File 'eicar.txt' is infected.
Tagging S3 object as 'infected'...
S3 object tagged successfully.
```

---

# Summary

Phase 5 introduces S3 Object Tagging into the malware scanning workflow.

Each uploaded file is now automatically tagged after scanning:

- `scan-status = clean`
- `scan-status = infected`

This provides a simple mechanism for downstream systems to determine the malware scan result without scanning the object again.