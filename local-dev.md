# Local Development Guide

This guide will help you set up and test your Lambda functions locally before deploying to AWS.

## Prerequisites

- Python 3.13 installed
- Docker Desktop installed
- uv package manager installed
- AWS CLI installed and configured

## Installing uv

If you don't have uv installed, install it using:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

For Windows users:
```powershell
powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
```

## Setting Up Your Development Environment

### 1. Navigate to a Lambda Function Directory

```bash
cd lambdas/resize  # or greyscale, or exif
```

### 2. Add Dependencies to pyproject.toml

Edit your `pyproject.toml` to include the dependencies you need. For example:

```toml
[project]
name = "resize-lambda"
version = "0.1.0"
description = "Lambda function to resize images"
requires-python = ">=3.13"
dependencies = [
    "pillow>=10.0.0",
    "boto3>=1.28.0"
]
```

### 3. Create a Virtual Environment and Install Dependencies

```bash
# Create a virtual environment
uv venv

# Activate the virtual environment
# On macOS/Linux:
source .venv/bin/activate

# On Windows:
.venv\Scripts\activate

# Install dependencies
uv pip install -e .
```

### 4. Implement Your Lambda Handler

Edit `handler.py` to implement your image processing logic. The handler should:
- Parse the SNS event to get S3 bucket and object key
- Download the image from S3
- Process the image (resize/greyscale/extract EXIF)
- Upload the result to the processed folder

## Local Testing

### Method 1: Test with Mock Events (Quick Testing)

Create a test event file `test-event.json`:

```json
{
  "Records": [
    {
      "EventSource": "aws:sns",
      "EventVersion": "1.0",
      "EventSubscriptionArn": "arn:aws:sns:us-east-1:123456789012:image-processing-topic:12345678-1234-1234-1234-123456789012",
      "Sns": {
        "Type": "Notification",
        "MessageId": "12345678-1234-1234-1234-123456789012",
        "TopicArn": "arn:aws:sns:us-east-1:123456789012:image-processing-topic",
        "Subject": "Amazon S3 Notification",
        "Message": "{\"Records\":[{\"eventVersion\":\"2.1\",\"eventSource\":\"aws:s3\",\"awsRegion\":\"us-east-1\",\"eventTime\":\"2024-01-01T12:00:00.000Z\",\"eventName\":\"ObjectCreated:Put\",\"s3\":{\"s3SchemaVersion\":\"1.0\",\"configurationId\":\"test-config\",\"bucket\":{\"name\":\"your-bucket-name\",\"arn\":\"arn:aws:s3:::your-bucket-name\"},\"object\":{\"key\":\"resize/test-image.jpg\",\"size\":1024}}}]}",
        "Timestamp": "2024-01-01T12:00:00.000Z"
      }
    }
  ]
}
```

### Method 2: Test with Docker (Most Realistic)

Build and test your Lambda container locally to ensure it works exactly as it will in AWS:

```bash
# build the Docker image
docker build -t resize-lambda:test .

# run the container
docker run -p 9000:8080 resize-lambda:test

# in another terminal, invoke the function with a test event
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
  -d @test-event.json
```

This method is closest to how your Lambda will run in production since it uses the actual Docker container.

## Debugging Tips

### AWS Credentials

For local testing with actual S3 buckets, ensure your AWS credentials are configured:

```bash
aws configure
```

Or set environment variables:
```bash
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_DEFAULT_REGION=us-east-1  # or whatever region you are using
```

## Manual Testing with AWS CLI

## Code Implementations

Each lambda already has `download_from_s3()` and `upload_to_s3()` helper functions. Here's the specific processing code for each:

### Resize to 512x512

```python
# download image from S3
image = download_from_s3(bucket_name, object_key)
print(f"Downloaded image: {image.size}")

# resize image to 512x512
resized_image = image.resize((512, 512), Image.Resampling.LANCZOS)
print(f"Resized to: {resized_image.size}")

# upload processed image to /processed/resize/
from pathlib import Path
filename = Path(object_key).name
output_key = f"processed/resize/{filename}"
upload_to_s3(bucket_name, output_key, resized_image)
print(f"Uploaded to: {output_key}")
```

### Greyscale

```python
# download image from S3
image = download_from_s3(bucket_name, object_key)
print(f"Downloaded image: {image.mode}")

# convert image to greyscale
greyscale_image = image.convert('L')
print(f"Converted to greyscale mode: {greyscale_image.mode}")

# upload processed image to /processed/greyscale/
from pathlib import Path
filename = Path(object_key).name
output_key = f"processed/greyscale/{filename}"
upload_to_s3(bucket_name, output_key, greyscale_image)
print(f"Uploaded to: {output_key}")
```

### EXIF

```python
# download image from S3
image = download_from_s3(bucket_name, object_key)

# extract EXIF metadata
exif_data = {
    'width': image.width,
    'height': image.height,
    'format': image.format,
    'mode': image.mode
}

# extract EXIF tags if available
if hasattr(image, 'getexif'):
    exif = image.getexif()
    if exif:
        for tag_id, value in exif.items():
            try:
                exif_data[str(tag_id)] = str(value)
            except Exception as e:
                print(f"Error processing tag {tag_id}: {e}")

print(f"Extracted EXIF data: {json.dumps(exif_data, indent=2)}")

# upload metadata to /processed/exif/ as JSON
from pathlib import Path
filename = Path(object_key).stem  # @note: get filename without extension
output_key = f"processed/exif/{filename}.json"
upload_to_s3(bucket_name, output_key, json.dumps(exif_data, indent=2), 'application/json')
print(f"Uploaded to: {output_key}")
```