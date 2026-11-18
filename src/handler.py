import json
import os

import boto3


def _get_table():
    return boto3.resource("dynamodb").Table(os.environ["STATUS_TABLE"])


def build_item(event):
    detail = event["detail"]
    object_detail = detail["object"]

    return {
        "event_id": event["id"],
        "record_type": "UPLOAD_EVENT",
        "status": "RECEIVED",
        "bucket": detail["bucket"]["name"],
        "object_key": object_detail["key"],
        "object_size": object_detail.get("size", 0),
        "received_at": event["time"],
    }


def lambda_handler(event, context):
    item = build_item(event)
    _get_table().put_item(Item=item)
    print(
        json.dumps(
            {
                "event_id": item["event_id"],
                "object_key": item["object_key"],
                "status": item["status"],
            }
        )
    )
    return item
