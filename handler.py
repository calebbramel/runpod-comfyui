"""
RunPod serverless handler entry point.
Patches S3 upload for Hetzner Object Storage compatibility.
"""
import os
import runpod
from runpod.serverless.utils import rp_upload
import botocore.config

# ---------------------------------------------------------------------------
# Patch get_boto_client — the base image's boto3 config is built for
# AWS/DigitalOcean. Hetzner requires virtual hosted-style addressing and
# disabled payload signing.
# ---------------------------------------------------------------------------
_original_get_boto_client = rp_upload.get_boto_client

def _hetzner_boto_client(bucket_creds=None):
    """Return a boto3 client configured for Hetzner Object Storage."""
    if bucket_creds is None:
        bucket_creds = {
            "endpoint_url": os.environ.get("BUCKET_ENDPOINT_URL"),
            "access_key_id": os.environ.get("BUCKET_ACCESS_KEY_ID"),
            "secret_access_key": os.environ.get("BUCKET_SECRET_ACCESS_KEY"),
        }

    endpoint = bucket_creds.get("endpoint_url")
    if not endpoint:
        return _original_get_boto_client(bucket_creds)

    import boto3
    from botocore.config import Config as BotoConfig

    # Extract region from endpoint (e.g. hel1 from hel1.your-objectstorage.com)
    region = "hel1"
    try:
        from urllib.parse import urlparse
        host = urlparse(endpoint).hostname or endpoint
        region = host.split(".")[0]
    except Exception:
        pass

    boto_config = BotoConfig(
        signature_version="s3v4",
        retries={"max_attempts": 3, "mode": "standard"},
        s3={
            "addressing_style": "virtual",
            "payload_signing_enabled": False,
        },
    )

    session = boto3.Session()
    return session.client(
        "s3",
        endpoint_url=endpoint,
        aws_access_key_id=bucket_creds.get("access_key_id"),
        aws_secret_access_key=bucket_creds.get("secret_access_key"),
        config=boto_config,
        region_name=region,
    )

rp_upload.get_boto_client = _hetzner_boto_client

# ---------------------------------------------------------------------------
# Patch upload_image — the base handler doesn't pass a bucket name, which
# defaults to month-year (e.g. "07-26"). Force our actual bucket name.
# ---------------------------------------------------------------------------
BUCKET_NAME = os.environ.get("BUCKET_NAME", "sanders-society44")

_original_upload = rp_upload.upload_image

def _patched_upload(job_id, image_path, bucket_name=None):
    return _original_upload(job_id, image_path, bucket_name=BUCKET_NAME)

rp_upload.upload_image = _patched_upload


def handler(event):
    """Delegates to the base image's ComfyUI worker at runtime."""
    import importlib
    base = importlib.import_module("handler")
    return base.handler(event)


if __name__ == "__main__":
    runpod.serverless.start({"handler": handler})
