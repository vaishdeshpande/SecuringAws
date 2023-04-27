import logging
import os
import boto3
from botocore.exceptions import ClientError

sns_client = boto3.client('sns',region_name='us-east-1')
TOPIC_ARN = os.environ.get('TOPIC_ARN')
def send_notification(event):
    subject = "Violation - IAM User is out of compliance"
    message = 'An IAM User was created in Production Account' + '\n\n'
    message += 'IAM ARN: ' + \
        event['detail']['responseElements']['user']['arn'] + ' \n'
    message += 'IAM User: ' + \
        event['detail']['responseElements']['user']['userName'] + ' \n'
    message += 'Event: ' + \
        event['detail']['eventName'] + '\n'
    message += 'Actor: ' + \
        event['detail']['userIdentity']['arn'] + '\n'
    message += 'Source IP Address: ' + \
        event['detail']['sourceIPAddress'] + '\n'
    message += 'User Agent: ' + \
        event['detail']['userAgent'] + '\n'
    try:
        sns_client.publish(
            TopicArn=TOPIC_ARN,
            Message=message,
            Subject=subject
        )
    except ClientError as err:
        logging.error(err)