import os
import unittest

os.environ["STATUS_TABLE"] = "test-status-table"

import handler


S3_EVENT = {
    "version": "0",
    "id": "17793124-05d4-b198-2fde-7ededc63b103",
    "detail-type": "Object Created",
    "source": "aws.s3",
    "account": "111122223333",
    "time": "2021-11-12T00:00:00Z",
    "region": "us-east-1",
    "resources": ["arn:aws:s3:::synthetic-feedback-bucket"],
    "detail": {
        "version": "0",
        "event-version": "1.2",
        "bucket": {"name": "synthetic-feedback-bucket"},
        "object": {
            "key": "incoming/workshop_feedback.csv",
            "size": 143,
            "etag": "b1946ac92492d2347c6235b4d2611184",
            "sequencer": "617f08299329d189",
        },
        "request-id": "N4N7GDK58NMKJ12R",
        "requester": "111122223333",
        "source-ip-address": "192.0.2.1",
        "reason": "PutObject",
    },
}


class FakeTable:
    def __init__(self):
        self.items = []

    def put_item(self, **kwargs):
        self.items.append(kwargs["Item"])
        return {}


class HandlerTests(unittest.TestCase):
    def setUp(self):
        self.table = FakeTable()
        handler._get_table = lambda: self.table

    def test_build_item_maps_s3_event_fields(self):
        item = handler.build_item(S3_EVENT)

        self.assertEqual(item["event_id"], S3_EVENT["id"])
        self.assertEqual(item["object_key"], "incoming/workshop_feedback.csv")
        self.assertEqual(item["status"], "RECEIVED")
        self.assertEqual(item["record_type"], "UPLOAD_EVENT")

    def test_lambda_handler_writes_one_item(self):
        result = handler.lambda_handler(S3_EVENT, None)

        self.assertEqual(len(self.table.items), 1)
        self.assertEqual(self.table.items[0], result)


if __name__ == "__main__":
    unittest.main()
