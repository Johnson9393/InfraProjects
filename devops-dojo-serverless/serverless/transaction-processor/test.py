import json

from main import lambda_handler

with open("test_event.json") as f:
    event = json.load(f)

response = lambda_handler(event, None)

print(response)