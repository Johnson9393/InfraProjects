#!/bin/bash

python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
gunicorn run:app --bind 0.0.0.0:8000 --daemon

sudo yum install git nginx -y
sudo yum install certbot python3-certbot-nginx -y