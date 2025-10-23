# ECR Setup Guide

## Overview

Amazon Elastic Container Registry (ECR) is a fully managed Docker container registry that makes it easy to store, manage, and deploy Docker container images. For this project, you'll create three separate ECR repositories to store your Lambda function container images.

## Prerequisites

- AWS Account
- AWS CLI installed and configured

## Step 1: Create ECR Repositories

You need to create three ECR repositories, one for each Lambda function. They must be named: resize-lambda, greyscale-lambda, and exif-lambda

Run the create repository command three times, once for each repository name:

```bash
aws ecr create-repository \
  --repository-name <REPO NAME> \
  --region <REPO REGION>
```

## Step 2: Verify Repository Creation

List your repositories to confirm they were created:

```bash
aws ecr describe-repositories --region <REPO REGION>
```

You should see output containing all three repositories:
```json
{
    "repositories": [
        {
            "repositoryArn": "arn:aws:ecr:us-east-1:AWS_ACCOUNT_ID:repository/resize-lambda",
            "registryId": "AWS_ACCOUNT_ID",
            "repositoryName": "resize-lambda",
            "repositoryUri": "AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/resize-lambda",
            "createdAt": "2025-10-21T16:39:45.936000-04:00",
            "imageTagMutability": "MUTABLE",
            "imageScanningConfiguration": {
                "scanOnPush": false
            },
            "encryptionConfiguration": {
                "encryptionType": "AES256"
            }
        },
        {
            "repositoryArn": "arn:aws:ecr:us-east-1:AWS_ACCOUNT_ID:repository/greyscale-lambda",
            "registryId": "AWS_ACCOUNT_ID",
            "repositoryName": "greyscale-lambda",
            "repositoryUri": "AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/greyscale-lambda",
            "createdAt": "2025-10-21T16:39:54.728000-04:00",
            "imageTagMutability": "MUTABLE",
            "imageScanningConfiguration": {
                "scanOnPush": false
            },
            "encryptionConfiguration": {
                "encryptionType": "AES256"
            }
        },
        {
            "repositoryArn": "arn:aws:ecr:us-east-1:AWS_ACCOUNT_ID:repository/exif-lambda",
            "registryId": "AWS_ACCOUNT_ID",
            "repositoryName": "exif-lambda",
            "repositoryUri": "AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/exif-lambda",
            "createdAt": "2025-10-21T16:40:02.178000-04:00",
            "imageTagMutability": "MUTABLE",
            "imageScanningConfiguration": {
                "scanOnPush": false
            },
            "encryptionConfiguration": {
                "encryptionType": "AES256"
            }
        }
    ]
}
```

## Step 3: Note Your Repository URIs

Each repository has a unique URI in the format:
```
{AWS_ACCOUNT_ID}.dkr.ecr.{AWS_REGION}.amazonaws.com/{REPOSITORY_NAME}
```

Get your repository URIs:

```bash
aws ecr describe-repositories \
  --repository-names resize-lambda greyscale-lambda exif-lambda \
  --region us-east-1 \
  --query 'repositories[*].[repositoryName,repositoryUri]' \
  --output table
```

Save these URIs - you'll need them later for GitHub Actions configuration.

## Cleanup (After Project Completion)

To delete repositories and all images:

```bash
aws ecr delete-repository --repository-name resize-lambda --force --region us-east-1
aws ecr delete-repository --repository-name greyscale-lambda --force --region us-east-1
aws ecr delete-repository --repository-name exif-lambda --force --region us-east-1
```
