import json
import boto3
from decimal import Decimal

# Initialize the DynamoDB client
dynamodb = boto3.resource('dynamodb')
# We will define this table name in Terraform later
table = dynamodb.Table('cloud-resume-challenge-visitor-counter')

class DecimalEncoder(json.JSONEncoder):
    """Helper class to convert DynamoDB Decimal types to standard JSON numbers"""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj)
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    try:
        # Atomic Update: Increment 'count' by 1 for the item where id='visitor_count'
        # If the item doesn't exist, it creates it with start value 0 + 1
        response = table.update_item(
            Key={'id': 'visitor_count'},
            UpdateExpression="ADD visit_count :inc",
            ExpressionAttributeValues={':inc': 1},
            ReturnValues="UPDATED_NEW"
        )
        
        # Get the new count
        new_count = response['Attributes']['visit_count']
        
        return {
            'statusCode': 200,
            'body': json.dumps({'count': new_count}, cls=DecimalEncoder)
        }
        
    except Exception as e:
        print(e)
        return {
            'statusCode': 500,
            'body': json.dumps('Error updating visitor count')
        }