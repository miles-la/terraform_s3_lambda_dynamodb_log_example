#
#   s3_object_deleted.py by Miles Baker of Linux Academy on July 2, 2019
#
#   Example Code Logging S3 Delete events to DynamoDB provided
#   by LinuxAcademy for illustrative purposes only
#
#   Environment variables to identify:
#       DYNAMODB_TABLE -> the name of the table used to log events
#
import boto3
import os
dynamodb = boto3.resource('dynamodb');
table = dynamodb.Table(os.environ['DYNAMODB_TABLE']);

print("Launch container for s3_object_deleted...");

def lambda_handler(event, context):
  try:
    # Cycle through records passed in S3 event notification
    for record in event['Records']:
        eventTime = record['eventTime'];
        bucket = record['s3']['bucket']['name'];
        name = record['s3']['object']['key'];
        message = '{0} applied to object: {1}/{2} at {3}'.format(record['eventName'], bucket, name, eventTime);

        #
        # Log message to CloudWatch
        print(message);

        #
        # Log message to DynamoDB
        table.put_item(
           Item={
                'object_name': '{0}/{1}'.format(bucket, name),
                'deleted_on': eventTime,
            }
        )

    return 'Success';

  except Exception as err:
    print("Error: Unable to log s3 object deletion.");
    print(err);
    return;
