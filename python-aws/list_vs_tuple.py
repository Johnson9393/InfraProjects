import boto3

#####################################################################################
#####################################################################################

# List ([]) - Mutable
# - Can add new elements using append() or extend()
# - Can remove elements using remove() or pop()
# - Can modify existing elements (e.g., users[0] = "admin")

# Tuple (()) - Immutable
# - Cannot add new elements after creation
# - Cannot remove elements after creation
# - Cannot modify existing elements (e.g., user[0] = "admin" raises an error)

#####################################################################################
#####################################################################################

# demo json parsing
# json_data = {
#     "user": "test-user",
#     "access_key": "AKIAIOSFODNN7EXAMPLE",
#     "secret_access_key": "wJalrXUtnFEMI/K7EXAMPLEKEY",
#     "nested": { "user_age" : 30 }
# }
# user = json_data["use"]
# access_key = json_data["access_key"]
# secret_access_key = json_data["secret_access_key"]

# user = json_data.get("use", "default-user")
# access_key = json_data.get("access_key")
# secret_access_key = json_data.get("secret_access_key")
# user_age = json_data.get("nested", {}).get("user_age", 0)

# print(f"User: {user}")
# print(f"Access Key: {access_key}")
# print(f"Secret Access Key: {secret_access_key}")
# print(f"User Age: {user_age}")

#####################################################################################
#####################################################################################

# iam_client = boto3.client('iam')

# response = iam_client.list_users()
# print(response.get('Users', []))
# print(type(response.get('Users')))
# user_data = response.get('Users', [])
# print(user_data[0])
# user_name = user_data[0].get('UserName')
# user_id = user_data[0].get('UserId')
# print(f"User Name: {user_name}")
# print(f"User ID: {user_id}")

# print users
# for user in user_data:
#     user_name = user.get('UserName')
#     user_id = user.get('UserId')
#     print(f"User Name: {user_name}")
#     print(f"User ID: {user_id}")

###########################################################################################
###########################################################################################


iam_client = boto3.client("iam")

def get_users():
    response = iam_client.list_users()
    users = response.get("Users", [])
    temp_list = []

    for user in users:
        user_name = user.get("UserName")
        user_id = user.get("UserId")
        temp_list.append([user_name, user_id]) # If we change this to tuple it throws an error "tuple object doesn't support"

    print("Before Modification:")
    print(temp_list)

    # Modify the first user's name
    temp_list[0][0] = "new_user"

    print("\nAfter Modification:")
    print(temp_list)

get_users()