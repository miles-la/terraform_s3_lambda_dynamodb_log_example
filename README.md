# Example Terraform Script for S3, Lambda, IAM and DynamoDB
This is an example Terraform script to create an S3 bucket, a lambda function, and a DynamoDB table.  

The lambda function is triggered when a file is deleted from the S3 bucket and logs a record into the DynamoDB table.
