# GitHub Actions Setup Guide

## Overview

GitHub Actions will automate the deployment of your Lambda functions. When you push code changes, the workflow will automatically build Docker images, push them to ECR, and update (or create) your Lambda functions.

## Prerequisites

- GitHub repository with this project code
- ECR repositories created ([ECR Setup](./ecr-setup.md))
- Lambda execution role created ([Lambda Setup](./lambda-setup.md))
- AWS CLI installed and configured

## Step 1: Get Your AWS Credentials

You'll need your AWS Access Key ID and Secret Access Key. If you don't have them:

```bash
# Get your current user
aws sts get-caller-identity

# If you need to create new access keys
aws iam create-access-key --user-name <your-iam-username>
```

**Important:** Keep these credentials secure and never commit them to your repository.

## Step 2: Add Secrets to GitHub Repository

Add the following secrets to your GitHub repository:

1. Go to your repository on GitHub
2. Click **Settings** > **Secrets and variables** > **Actions**
3. Click **New repository secret**
4. Add these three secrets:

### AWS_ACCESS_KEY_ID
Value: Your AWS Access Key ID

### AWS_SECRET_ACCESS_KEY
Value: Your AWS Secret Access Key

### LAMBDA_ROLE_ARN
Value: The Lambda execution role ARN from [Lambda Setup](./lambda-setup.md)

Example: `arn:aws:iam::123456789012:role/lambda-image-processing-role`

You can retrieve the role ARN:

```bash
aws iam get-role \
  --role-name lambda-image-processing-role \
  --query 'Role.Arn' \
  --output text
```

## Step 3: Understanding the GitHub Actions Workflow

The workflow file is located at `.github/workflows/deploy.yml`. This workflow is already implemented and will automatically build, push, and deploy your Lambda functions when you push to the main branch.

### Key Configuration: AWS Credentials

The workflow uses your GitHub secrets to authenticate with AWS. Please notice that secret values are prefixed with `secrets.` and environment variables are prefixed with `env.`:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: ${{ env.AWS_REGION }}
```

This step:
- Reads your AWS credentials from GitHub secrets
- Configures the GitHub Actions runner to use these credentials
- Sets the AWS region for all subsequent AWS CLI commands

### Workflow Structure

The workflow has three jobs, one for each Lambda function:
1. `deploy-resize` - Builds and pushes resize-lambda
2. `deploy-greyscale` - Builds and pushes greyscale-lambda
3. `deploy-exif` - Builds and pushes exif-lambda

Each job:
1. Checks out your code
2. Configures AWS credentials using the secrets
3. Logs into Amazon ECR
4. Builds the Docker image
5. Tags and pushes the image to ECR
6. Creates or updates the Lambda function

## Step 4: Update the Lambda Role ARN

You need to update the `AWS_LAMBDA_ROLE_ARN` environment variable in `.github/workflows/deploy.yml` with the role ARN you created in the Lambda Setup guide.

### Example: Build, Tag, and Push Step

Here's what the `deploy-greyscale` job should look like:

```yaml
- name: Build, tag, and push greyscale image to Amazon ECR
  env:
    ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
    ECR_REPOSITORY: greyscale-lambda
    IMAGE_TAG: ${{ github.sha }}
  run: |
    cd lambdas/greyscale
    docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
    docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
    docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
    docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
    echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT
```

### Understanding the Docker Commands

1. **Navigate to lambda directory**: `cd lambdas/greyscale`
   - Changes to the directory containing the Dockerfile

2. **Build the image**: `docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .`
   - Builds the Docker image using the Dockerfile
   - Tags it with your ECR registry URL and the git commit SHA

3. **Tag with latest**: `docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest`
   - Creates an additional tag `latest` pointing to the same image
   - Useful for always referencing the most recent version

4. **Push specific tag**: `docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG`
   - Pushes the image with the commit SHA tag to ECR

5. **Push latest tag**: `docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest`
   - Pushes the latest tag to ECR

6. **Output image uri**: `echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT`
   - save the newly deployed image into a variable

## Step 5: Verify Deployment

After the workflow completes successfully, verify your Lambda functions were created/updated:

```bash
# List Lambda functions
aws lambda list-functions \
  --query 'Functions[?contains(FunctionName, `lambda`)].FunctionName' \
  --region us-east-1

# Check function details
aws lambda get-function --function-name greyscale-lambda --region us-east-1

# Verify the image URI points to your ECR
aws lambda get-function --function-name greyscale-lambda --region us-east-1 \
  --query 'Code.ImageUri' \
  --output text
```
