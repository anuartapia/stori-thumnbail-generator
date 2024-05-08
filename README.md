# Stori's Data Engineering coding assessment

## Thumbnail Generator
This Thumbnail Generator is implemented using AWS Services: S3, Lambda, IAM; Python code with [PIL](https://pillow.readthedocs.io/en/stable/reference/Image.html) library for image manipulation; and Terraform as deployment tool.

### Design and Architecture
AWS S3 service provides a built-in mechanism to create a Bucket Notification for several kinds of events. `s3:ObjectCreated` event is triggered everytime an object is created. This mechanism supports binding to one or multiple AWS Lambda functions.

For the `Thumbnail Generator` use case. We will create a S3 Bucket to store the original images (`stori-original-image-bucket`), then configure a Bucket Notification to trigger a Lambda function that reduces the image size, and writes the new image into another S3 Bucket with the thumbnails (`stori-thumbnail-image-bucket`).

![Architecture](/Architecture.png)

## Deployment
Make sure your AWS CLI profile is correctly set up, then deploy this project by running the following commands
```bash
# prepare and create deployment on AWS
> terraform init
> terraform plan
> terraform apply
# upload image
> aws s3 cp <large-image-file> s3://stori-original-image-bucket
# wait a bit, then check the result
> aws s3 ls s3://stori-thumbnail-image-bucket
# check logs
> aws logs tail /aws/lambda/thumbnail_generation_lambda
# download generated thumbnail
> aws s3api get-object --bucket stori-thumbnail-image-bucket --key <thumbnail-image-file> result.jpg
# delete test files
> aws s3 rm s3://stori-original-image-bucket --recursive
> aws s3 rm s3://stori-thumbnail-image-bucket --recursive
# destroy deployment created on AWS
> terraform destroy
```

## Strengths
- **Simplicity**. The implementation is quite simple and compliant with its purpose.
- **Security**. Policy, Roles, and Permissions are configured in a standardized manner.
- **Visibility**. Cloudwatch Logs are enabled for the Lambda function.
## Weaknesses
- **Workload**. Bucket Notifications face some [limitations](https://docs.aws.amazon.com/AmazonS3/latest/userguide/EventNotifications.html) such as delivery time and throughput capability.
- **Duplicates**. This implementation does not support processing different files with the same name.
## Improvements
- **Scalability**. Bucket Notifications limitations are resolved by adding SNS and SQS layers. SNS layer would be the direct single destination for `s3:ObjectCreated` events, SNS supports high throughput to multiple subscribers. SQS layer guarantees 1:1 communication reliability, also it provides a failover mechanism with Dead-Letter Queue configuration.
- **Error handling**. Dead-Letter Queues can be subscribed by a Failover Lambda function to debug, alert, and process failed events.
- **Partitions**. Different files with same name may be processed, by storing the files into separate folders (partitions e.g. by date) inside the same bucket. Object keys may include a prefix to with upload date. This strategy also helps to reduce latency by setting search boundaries.
- **Alt Text** feature. Alternative Text for images used in the internet is an [important](https://moz.com/learn/seo/alt-text) feature. As it helps to provide context for humans, search engines, and accessibility tools. We can include an automated implementation of this feature in our Thumbnail Generator to make it cooler. A Lambda function using the AWS Bedrock service, and writing the result to another bucket would be enough.

## Improved Architecture
Below is an illustration of an improved Architecture with the considerations mentioned before.
![Architecture-improved](/Architecture-improved.png)