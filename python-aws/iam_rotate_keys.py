import boto3
from datetime import datetime, timezone, timedelta #importing this to convert date into age

# Problem Statement: Delete access keys of a user If the keys are older than 2 days from local and lambda

# Algo: 
# 1. Get the list of users and from users get the username
# 2. Get access keys and create date from all the users
# 3. create delete keys function from boto3 and pass arguments as user_name and access_key_id
# 4. Create a function to return access keys of all users upon condition if age > 2 days 
# 5. Create main function to delete the keys that are older than 2 days and delete them


iam_client = boto3.client('iam')

def get_users():
    response = iam_client.list_users()
    users = response.get('Users', [])
    temp_list = []

    for user in users:
      user_name = user.get('UserName')
      temp_list.append(user_name)
    
    return temp_list

# This usually gives only for a specific users
def get_access_keys(user_name):
   response = iam_client.list_access_keys(UserName = user_name)
   meta_data = response.get('AccessKeyMetadata', [])

   temp_list = []

   for data in meta_data:
      access_key_id = data.get('AccessKeyId')
      create_date = data.get('CreateDate')
      current_date = datetime.now(timezone.utc)
      age = (current_date - create_date).days
      temp_list.append( (user_name, access_key_id, age) )

   return temp_list

def get_keys_from_all_users():
   users = get_users()
   temp_list_for_user_access_keys = []

   for user in users:
      access_keys = get_access_keys(user)
      temp_list_for_user_access_keys.append(access_keys)

   return temp_list_for_user_access_keys

def delete_access_key(user_name, access_key_id):
   response = iam_client.delete_access_key(
      UserName = user_name,
      AccessKeyId = access_key_id
    )
   
   print(f"Deleted access key: {access_key_id} for user: {user_name}")
   return response

def keys_to_delete():
   keys_info = get_keys_from_all_users()
   expiry_days = 2
   temp = []

   for keys in keys_info:
      for key in keys:
         user_name, access_key_id, age = key
         if age > expiry_days:
            temp.append((user_name, access_key_id))

   return temp


def run():
   delete_keys = keys_to_delete()
   for keys in delete_keys:
      print(f"Deleting access key: {keys[1]} for user: {keys[0]}")
      delete_access_key(keys[0], keys[1])


def lambda_handler(event, context):
    run()



