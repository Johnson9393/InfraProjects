"""
ClamAV helper functions for malware scanning.
"""

import clamd


def scan_file(local_file_path):
    """Scans a file using the ClamAV daemon."""

    print("Connecting to ClamAV daemon...")

    cd = clamd.ClamdUnixSocket()

    print(f"Scanning file: {local_file_path}")

    result = cd.scan(local_file_path)

    print(f"Scan Result: {result}")

    return result