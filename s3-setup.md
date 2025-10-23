# S3 Bucket Setup Guide

## Overview

Amazon S3 (Simple Storage Service) will serve as the trigger point for your event-driven architecture. When images are uploaded to specific prefixes in your bucket, they will trigger your Lambda functions through SNS.

## Prerequisites

- AWS Account
- AWS CLI installed and configured
- Your Pitt username

## Step 1: Create S3 Bucket

Your bucket name must follow the format: `{pitt-username}-assignment3`

For example, if your Pitt username is `dpm79`, your bucket name will be: `dpm79-assignment3`

```bash
# Replace <your-pitt-username> with your actual Pitt username
aws s3 mb s3://<your-pitt-username>-assignment3 --region us-east-1
```

Example:
```bash
aws s3 mb s3://dpm79-assignment3 --region us-east-1
```

## Step 2: Create Required Prefixes (Folders)

Your bucket needs six prefixes to organize input and processed images:

**Input prefixes:**
- `resize/`
- `greyscale/`
- `exif/`

**Output prefixes:**
- `processed/resize/`
- `processed/greyscale/`
- `processed/exif/`

```bash
# Replace <your-pitt-username> with your actual Pitt username
BUCKET_NAME="<your-pitt-username>-assignment3"

# Create input prefixes
aws s3api put-object --bucket $BUCKET_NAME --key resize/
aws s3api put-object --bucket $BUCKET_NAME --key greyscale/
aws s3api put-object --bucket $BUCKET_NAME --key exif/

# Create processed output prefixes
aws s3api put-object --bucket $BUCKET_NAME --key processed/resize/
aws s3api put-object --bucket $BUCKET_NAME --key processed/greyscale/
aws s3api put-object --bucket $BUCKET_NAME --key processed/exif/
```

## Step 3: Verify Bucket Structure

Check that all prefixes were created:

```bash
aws s3 ls s3://<your-pitt-username>-assignment3/
```

You should see output similar to:
```
                           PRE exif/
                           PRE greyscale/
                           PRE processed/
                           PRE resize/
```

## Step 4: Configure S3 Event Notifications

S3 event notifications will be configured in the [SNS Setup Guide](./sns-setup.md) after creating your SNS topic.

## Step 5: Make Bucket Public (For Grading Only)
You bucket needs to be made public for grading purposes

Create a file named `bucket-policy.json` (update pitt id):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:List*"
      ],
      "Resource": [
        "arn:aws:s3:::<your-pitt-username>-assignment3",
        "arn:aws:s3:::<your-pitt-username>-assignment3/*"
      ]
    }
  ]
}

```

Apply the policy and disable block public access:

```bash
# disable block public access
aws s3api put-public-access-block \
--bucket <your-pitt-username>-assignment3 \
--public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

# apply bucket policy
aws s3api put-bucket-policy --bucket <your-pitt-username>-assignment3 --policy file://bucket-policy.json
```

## Bucket Structure Summary

```
<your-pitt-username>-assignment3/
├── resize/                    # Upload images here for resize processing
├── greyscale/                 # Upload images here for greyscale processing
├── exif/                      # Upload images here for EXIF extraction
└── processed/
    ├── resize/                # Resized images output here
    ├── greyscale/             # Greyscale images output here
    └── exif/                  # EXIF JSON files output here
```

## Cleanup (After Project Completion)

```bash
# Delete all objects first
aws s3 rm s3://<your-pitt-username>-assignment3 --recursive

# Delete the bucket
aws s3 rb s3://<your-pitt-username>-assignment3
```
