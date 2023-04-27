from send_notification import send_notification

def lambda_handler(event,context):
    create_user = event['detail']['eventName']

    if create_user == 'CreateUser':
        send_notification(event)