# StudentLMSApp

StudentLMSApp is a Flask-based 3-tier application to manage students and track attendance.
Deployed on AWS EC2 using Nginx, Gunicorn, and PostgreSQL.

---

## Application Setup

```bash id="g2q4p7"
cd StudentProfileApp   # move into project directory

python3 -m venv .venv  # create virtual environment
source .venv/bin/activate  # activate environment

pip install -r requirements.txt  # install dependencies
```

---

## Database Setup (PostgreSQL)

---

### Install PostgreSQL

```bash id="z9z3n8"
sudo dnf install postgresql15-server postgresql15 -y   # install postgres server + client

sudo postgresql-setup --initdb   # initialize database cluster

sudo systemctl enable postgresql --now   # start and enable service

sudo systemctl status postgresql   # verify service is running
```

---

### Create Database

```bash id="s7o3jw"
psql -U postgres -h localhost   # connect to postgres shell
```

```sql id="y2b45v"
ALTER USER postgres WITH PASSWORD 'password';   -- set DB password for app auth

CREATE DATABASE mydb;   -- create application database

\l   -- list databases

\q   -- exit postgres shell
```

---

### Configure Authentication

Switch from `ident` → `md5` to allow password-based login from apps.

```bash id="nq1i0p"
sudo vi /var/lib/pgsql/data/pg_hba.conf   # open auth config file
```

```text id="3i2jzn"
host    all    all    127.0.0.1/32    md5
host    all    all    ::1/128         md5
```

```bash id="3u6g9h"
sudo systemctl restart postgresql   # apply auth changes
```

---

### Test DB

```bash id="j7z1lw"
export DB_LINK="postgresql://postgres:password@localhost:5432/mydb"   # connection string

psql $DB_LINK   # test DB connectivity
```

---

## Run Application

```bash id="q1f87u"
export DB_LINK="postgresql://postgres:password@localhost:5432/mydb"   # set env variable

python run.py   # start flask app (dev server)
```

```bash id="6qzq2x"
curl localhost:8000   # test app response
```

---

## Gunicorn (Production)

```bash id="3k6w3n"
gunicorn app:app --bind 127.0.0.1:8000   # run production WSGI server
```

---

## Gunicorn Service

```bash id="7w0w0v"
sudo vi /etc/systemd/system/gunicorn.service   # create service file
```

```ini id="0s1n0q"
[Unit]
Description=Gunicorn service
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/home/ec2-user/StudentProfileApp
Environment="PATH=/home/ec2-user/StudentProfileApp/.venv/bin"
Environment="DB_LINK=postgresql://postgres:password@localhost:5432/mydb"

ExecStart=/home/ec2-user/StudentProfileApp/.venv/bin/gunicorn --workers 3 --bind 127.0.0.1:8000 app:app   # start gunicorn
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash id="l6kq5l"
sudo systemctl daemon-reload   # reload systemd configs
sudo systemctl start gunicorn   # start service
sudo systemctl enable gunicorn   # enable on boot
```

---

## Nginx Configuration

```bash id="q7o6yx"
sudo vi /etc/nginx/nginx.conf   # open nginx config
```

```nginx id="x3r0s5"
server {
    listen 80;
    server_name your-domain;

    location / {
        proxy_pass http://127.0.0.1:8000;   # forward traffic to backend app
    }
}
```

```bash id="s0z8lu"
sudo systemctl restart nginx   # apply nginx config
```

---

## HTTPS Setup (Certbot)

```bash id="7t3h0d"
sudo dnf install certbot python3-certbot-nginx -y   # install certbot
```

```bash id="7c5f9x"
sudo certbot --nginx \
-d your-domain \
-d www.your-domain   # generate SSL + auto configure nginx
```

```nginx id="y3f9a6"
return 301 https://$host$request_uri;   # redirect HTTP → HTTPS
```

```bash id="v3p7xn"
sudo certbot renew --dry-run   # test auto renewal
```

---

## Database Backup

```bash id="6k4k3g"
export DB_LINK="postgresql://postgres:password@localhost:5432/mydb"

pg_dump -Fc $DB_LINK -f /tmp/mydb_$(date +%Y%m%d_%H%M%S).dump   # create compressed backup

ls -lh /tmp/mydb_*.dump   # verify dump file
```

```bash id="z3r8su"
# pick latest dump file automatically
# ls -t → latest first | head -1 → pick newest
DUMP_FILE=$(ls -t /tmp/mydb_*.dump | head -1)

echo $DUMP_FILE   # print selected file
```

---

## Backup to S3

S3 is used for durable backup storage.

IAM Role is preferred over `aws configure` because:

* No static credentials
* More secure
* Auto rotation

```bash id="k8l1r9"
aws s3 cp $DUMP_FILE s3://your-bucket-name/backups/   # upload dump to S3

aws s3 ls s3://your-bucket-name/backups/   # verify upload
```

---

## Restore Database

```bash id="y2o8b6"
aws s3 cp s3://your-bucket-name/backups/your-file.dump /tmp/restore.dump   # download backup

psql -U postgres -c "DROP DATABASE IF EXISTS mydb;"   # drop existing DB
psql -U postgres -c "CREATE DATABASE mydb;"   # recreate DB

pg_restore -Fc -d $DB_LINK /tmp/restore.dump   # restore backup

psql $DB_LINK -c "\dt"   # verify tables
```

---

## Summary

* Flask → Application
* Gunicorn → Production server
* Nginx → Reverse proxy
* PostgreSQL → Database
* Certbot → HTTPS
* S3 → Backup storage
