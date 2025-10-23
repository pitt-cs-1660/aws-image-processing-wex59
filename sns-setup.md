# SNS Topic Setup Guide

## Overview

Amazon SNS (Simple Notification Service) acts as the routing layer in your event-driven architecture. When images are uploaded to S3, S3 sends notifications to SNS, which then routes them to the appropriate Lambda function based on the S3 object prefix.

## Prerequisites

- S3 bucket created ([S3 Setup](./s3-setup.md))
- Lambda functions created ([Lambda Setup](./lambda-setup.md))
- AWS CLI installed and configured

## Step 1: Create SNS Topic

```bash
aws sns create-topic \
  --name image-processing-topic \
  --region us-east-1
```

Save the Topic ARN from the output:
```json
{
    "TopicArn": "arn:aws:sns:us-east-1:<ACCOUNT ID>:image-processing-topic"
}
```

You can also retrieve it later:

```bash
aws sns list-topics --region us-east-1 --query 'Topics[?contains(TopicArn, `image-processing-topic`)].TopicArn' --output text
```

## Step 2: Grant S3 Permission to Publish to SNS

Create a file named `sns-topic-policy.json` (replace `<AWS_ACCOUNT_ID>` and `<your-pitt-username>`):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Action": "SNS:Publish",
      "Resource": "arn:aws:sns:us-east-1:<AWS_ACCOUNT_ID>:image-processing-topic",
      "Condition": {
        "StringEquals": {
          "aws:SourceAccount": "<AWS_ACCOUNT_ID>"
        },
        "ArnLike": {
          "aws:SourceArn": "arn:aws:s3:::<your-pitt-id>-assignment3"
        }
      }
    }
  ]
}
```

Apply the policy:

```bash
aws sns set-topic-attributes \
  --topic-arn arn:aws:sns:us-east-1:<AWS_ACCOUNT_ID>:image-processing-topic \
  --attribute-name Policy \
  --attribute-value file://sns-topic-policy.json \
  --region us-east-1
```

## Step 3: Subscribe Lambda Functions to SNS Topic

Subscribe each Lambda function to the SNS topic with filter policies based on S3 object key prefixes.

**Note:** Due to API limitations with the AWS CLI for setting complex filter policies, we recommend using the AWS Console for this step.

### Subscribe resize-lambda

1. Navigate to **Amazon SNS** in the AWS Console
2. Click on **Topics** in the left sidebar
3. Click on your **image-processing-topic**
4. Click **Create subscription**
5. Configure the subscription:
   - **Protocol**: AWS Lambda
   - **Endpoint**: Select `resize-lambda` from the dropdown
   - Click **Create subscription**

6. Once created, click on the subscription (the Subscription ID will be a long ARN)
7. Click **Edit**
8. Scroll down to **Subscription filter policy**
9. Select **Message body** (not Message attributes)
10. In the JSON editor, paste the following filter policy:

```json
{
  "Records": {
    "s3": {
      "object": {
        "key": [
          {
            "prefix": "resize/"
          }
        ]
      }
    }
  }
}
```

11. Click **Save changes**

### Subscribe greyscale-lambda

1. Return to your **image-processing-topic** page
2. Click **Create subscription**
3. Configure the subscription:
   - **Protocol**: AWS Lambda
   - **Endpoint**: Select `greyscale-lambda` from the dropdown
   - Click **Create subscription**

4. Click on the new subscription
5. Click **Edit**
6. Scroll down to **Subscription filter policy**
7. Select **Message body**
8. Paste the following filter policy:

```json
{
  "Records": {
    "s3": {
      "object": {
        "key": [
          {
            "prefix": "greyscale/"
          }
        ]
      }
    }
  }
}
```

9. Click **Save changes**

### Subscribe exif-lambda

1. Return to your **image-processing-topic** page
2. Click **Create subscription**
3. Configure the subscription:
   - **Protocol**: AWS Lambda
   - **Endpoint**: Select `exif-lambda` from the dropdown
   - Click **Create subscription**

4. Click on the new subscription
5. Click **Edit**
6. Scroll down to **Subscription filter policy**
7. Select **Message body**
8. Paste the following filter policy:

```json
{
  "Records": {
    "s3": {
      "object": {
        "key": [
          {
            "prefix": "exif/"
          }
        ]
      }
    }
  }
}
```

9. Click **Save changes**

**Important Notes:**
- The filter policy must be applied to the **message body** (not message attributes)
- The S3 event notification structure includes `Records.s3.object.key` which contains the object key
- Each Lambda will only receive notifications for objects with their specific prefix
- The AWS Console provides a more reliable interface for setting complex filter policies compared to the CLI

## Step 4: Verify Subscriptions

List all subscriptions to your topic:

```bash
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-east-1:<ACCOUNT ID>:image-processing-topic \
  --region us-east-1
```

You should see three subscriptions with status "Confirmed" (Lambda subscriptions auto-confirm).

## Step 5: Configure S3 Event Notifications

Now configure your S3 bucket to send notifications to SNS when objects are uploaded.

Create a file named `s3-notification-config.json` (replace `<AWS_ACCOUNT_ID>`):

```json
{
  "TopicConfigurations": [
    {
      "TopicArn": "arn:aws:sns:us-east-1:<AWS_ACCOUNT_ID>:image-processing-topic",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            {
              "Name": "prefix",
              "Value": "resize/"
            }
          ]
        }
      }
    },
    {
      "TopicArn": "arn:aws:sns:us-east-1:<AWS_ACCOUNT_ID>:image-processing-topic",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            {
              "Name": "prefix",
              "Value": "greyscale/"
            }
          ]
        }
      }
    },
    {
      "TopicArn": "arn:aws:sns:us-east-1:<AWS_ACCOUNT_ID>:image-processing-topic",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            {
              "Name": "prefix",
              "Value": "exif/"
            }
          ]
        }
      }
    }
  ]
}
```

Apply the notification configuration:

```bash
aws s3api put-bucket-notification-configuration \
  --bucket <your-pitt-username>-assignment3 \
  --notification-configuration file://s3-notification-config.json \
  --region us-east-1
```

## Step 6: Verify S3 Event Notifications

Check that the notifications were configured:

```bash
aws s3api get-bucket-notification-configuration \
  --bucket <your-pitt-username>-assignment3 \
  --region us-east-1
```

You should see the three TopicConfigurations you just created.

## Testing the Complete Flow

Test the entire event-driven architecture:

```bash
# Download a test image
curl -o test-resize.jpg https://picsum.photos/800/600

# Upload to resize prefix - should trigger resize-lambda
aws s3 cp test-resize.jpg s3://<your-pitt-username>-assignment3/resize/test-resize.jpg

# Wait a few seconds, then check processed folder
aws s3 ls s3://<your-pitt-username>-assignment3/processed/resize/

# Check CloudWatch Logs for Lambda execution
aws logs tail /aws/lambda/resize-lambda --follow --region us-east-1
```

Repeat for greyscale and exif prefixes.

## Understanding the Message Flow

```
S3 Upload (resize/image.jpg)
    |
S3 Event Notification
    |
SNS Topic (image-processing-topic)
    |
SNS Filter Policy checks prefix
    |
Only resize-lambda receives notification
    |
Lambda processes image
    |
Processed image uploaded to processed/resize/
```

## Cleanup (After Project Completion)

```bash
# List and delete subscriptions
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-east-1:<AWS_ACCOUNT_ID>:image-processing-topic \
  --query 'Subscriptions[*].SubscriptionArn' \
  --output text | xargs -I {} aws sns unsubscribe --subscription-arn {} --region us-east-1

# Delete SNS topic
aws sns delete-topic \
  --topic-arn arn:aws:sns:us-east-1:<AWS_ACCOUNT_ID>:image-processing-topic \
  --region us-east-1

# Remove S3 event notifications
aws s3api put-bucket-notification-configuration \
  --bucket <your-pitt-username>-assignment3 \
  --notification-configuration '{}' \
  --region us-east-1
```
