import boto3
import csv
from io import StringIO
from db import get_db_connection
from datetime import datetime, UTC

s3 = boto3.client("s3")


def read_s3_object(bucket, key):
    response = s3.get_object(Bucket=bucket, Key=key)
    content = response["Body"].read().decode("utf-8") # This line says to read the content of the file from the response and decode it from bytes to a string using UTF-8 encoding.
    return content

# Parsing the csv into a python objects to insert data into DB. The parse_csv function takes the content of the CSV file as input and uses the csv.DictReader class to read the CSV data into a list of dictionaries, where each dictionary represents a row in the CSV file.
def parse_csv(content):

    csv_reader = csv.DictReader(StringIO(content)) # it will read the CSV data from the content string and convert it into a list of dictionaries, where each dictionary represents a row in the CSV file. The StringIO class is used to create an in-memory file-like object from the content string, which can be read by the csv.DictReader class.

    records = []

    for row in csv_reader:
        records.append(row)

    return records

# Creating upload transaction function to generate a transaction ID and insert the data.

def create_upload_transaction(connection, bucket, key):

    file_name = key.split("/")[-1]

    query = """
    INSERT INTO upload_transactions
    (
        file_name,
        bucket_name,
        object_key,
        status
    )
    VALUES
    (
        %s,
        %s,
        %s,
        %s
    )
    RETURNING id;
    """

    with connection.cursor() as cursor: # cursor object is created to execute the SQL query. The cursor is used to interact with the database and perform operations such as executing queries and fetching results.

        cursor.execute(
            query,
            (
                file_name,
                bucket,
                key,
                "PROCESSING"
            )
        )  #This line executes the SQL query using the cursor object. The query is passed as a string, and the values for the placeholders (%s) are provided as a tuple. The execute method sends the query to the database for execution.

        transaction_id = cursor.fetchone()[0] #This line fetches the first row of the result set returned by the query and retrieves the first column value (the transaction ID) from that row. The transaction ID is then stored in the transaction_id variable.

    return transaction_id


# This will insert the uploaded questions into the database.
def insert_uploaded_questions(connection, transaction_id, records):

    query = """
    INSERT INTO uploaded_questions
    (
        transaction_id,
        topic_slug,
        question_text,
        option1,
        option2,
        option3,
        option4,
        correct_answer,
        created_at
    )
    VALUES
    (
        %s,
        %s,
        %s,
        %s,
        %s,
        %s,
        %s,
        %s,
        %s
    );
    """

    with connection.cursor() as cursor:

        for record in records:
            cursor.execute(
                query,
                (
                    transaction_id,
                    record["topic_slug"],
                    record["question_text"],
                    record["option1"],
                    record["option2"],
                    record["option3"],
                    record["option4"],
                    int(record["correct_answer"]),
                    datetime.now(UTC)
                )
            )



def update_upload_transaction(
    connection,
    transaction_id,
    status,
    total_records,
    success_records,
    failed_records,
    validation_error=None
):

    query = """
    UPDATE upload_transactions
    SET
        status = %s,
        total_records = %s,
        success_records = %s,
        failed_records = %s,
        validation_error = %s,
        processed_at = CURRENT_TIMESTAMP
    WHERE id = %s;
    """

    with connection.cursor() as cursor:

        cursor.execute(
            query,
            (
                status,
                total_records,
                success_records,
                failed_records,
                validation_error,
                transaction_id
            )
        )


# Events are sent to the Lambda function in a specific format. The event parameter contains information about the S3 event that triggered the Lambda function, and the context parameter contains runtime information about the Lambda function.

# using try-except-finally block to handle exceptions and ensure that the database connection is closed properly after the function execution.
def lambda_handler(event, context):

    connection = None
    transaction_id = None
    records = []

    try:
        bucket = event["Records"][0]["s3"]["bucket"]["name"] # extract bucket name from the first record in the event 
        key = event["Records"][0]["s3"]["object"]["key"] # extract object key from the event

        print(f"Bucket : {bucket}")
        print(f"Key : {key}")

        content = read_s3_object(bucket, key) # passing the bucket and key to the read_s3_object function to get the content of the file
        
        records = parse_csv(content)
        print(records)

        connection = get_db_connection()
        transaction_id = create_upload_transaction(
        connection,
        bucket,
        key
    )
        connection.commit()

        insert_uploaded_questions(
        connection,
        transaction_id,
        records
    )
        update_upload_transaction(
        connection,
        transaction_id,
        status="SUCCESS",
        total_records=len(records),
        success_records=len(records),
        failed_records=0
    )
        connection.commit() # commit the transaction to the database to make the changes permanent

        print(f"Transaction ID : {transaction_id}")

        return {
            "statusCode": 200,
            "body": "CSV processed successfully"
        }

    except Exception as e:

        if connection:
            connection.rollback()

            update_upload_transaction(
            connection,
            transaction_id,
            status="FAILED",
            total_records=len(records),
            success_records=0,
            failed_records=len(records),
            validation_error=str(e)
        )
            
            connection.commit()

        print(f"Error : {e}")

        raise

    finally:
        
        if connection:
            connection.close()