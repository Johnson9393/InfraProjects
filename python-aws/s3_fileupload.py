import boto3;

# Problem Statement: create a bucket and upload a file to an s3 bucket using boto3 from local and uisng lambda function

# print(boto3.Session().region_name) 

# bucket_name = "storage0309"
# region = "us-east-1"
# s3_client = boto3.client('s3')
# create_bucket() is a aws built in function that can be used directly
# if region == "us-east-1":
#     response = s3_client.create_bucket(Bucket = bucket_name)
# else:
#     response = s3_client.create_bucket(
#         Bucket = bucket_name,
#         CreateBucketConfiguration = {
#             "LocationConstraint": region
#         }
#     )

# print(response)


# Upload a file to the bucket

# s3_client.upload_file("README.md", bucket_name, "readme.md")


#######################
# Using functions and best practices
########################
region = "us-east-1"
s3_client= boto3.client("s3")

def create_bucket(bucket_name):
    print(f'Creating Bucket: {bucket_name}') #f string is used to maintain the logs and replace the paramter values
    if region == "us-east-1":
        response = s3_client.create_bucket(Bucket = bucket_name)
    else:
        response = s3_client.create_bucket(
            Bucket = bucket_name,
            CreateBucketConfiguration = {
                "LocationConstraint": region
            }
        )
    print(response)


def upload_file(local_file_path, bucket_name, s3_file_path):
    print(f'Uploading file: {local_file_path} to bucket: {bucket_name} as {s3_file_path}')
    s3_client.upload_file(local_file_path, bucket_name, s3_file_path)


def run():
    bucket_name = "storage0309"
    local_file_path = "README.md"
    s3_file_path = "readme.md"
    create_bucket(bucket_name)
    upload_file(local_file_path, bucket_name, s3_file_path)


run()






