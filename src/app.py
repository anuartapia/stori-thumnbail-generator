import logging
import boto3
from io import BytesIO
from PIL import Image
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, _):
    # source bucket and key
    bucket = event["Records"][0]["s3"]["bucket"]["name"]
    key = event["Records"][0]["s3"]["object"]["key"]

    # target bucket and key
    thumbnail_bucket = os.environ["thumbnail_bucket"]
    thumbnail_name, thumbnail_extension = os.path.splitext(key)
    thumbnail_key = f"{thumbnail_name}_thumbnail{thumbnail_extension}"

    logger.info(
        f"Source Bucket: {bucket}, Source Key: {key}, Target Bucket: {thumbnail_bucket}, Target Key: {thumbnail_key}")

    # create s3 client and read image
    s3_client = boto3.client('s3')
    file_byte_string = s3_client.get_object(Bucket=bucket, Key=key)['Body'].read()
    img = Image.open(BytesIO(file_byte_string))

    # generate thumbnail
    width = int(os.environ["max_width"])
    height = int(os.environ["max_height"])
    img.thumbnail((width, height))

    # save result to a IO buffer
    buffer = BytesIO()
    img.save(buffer, "JPEG")
    buffer.seek(0)

    # create object in target bucket
    sent_data = s3_client.put_object(Bucket=thumbnail_bucket, Key=thumbnail_key, Body=buffer)

    if sent_data['ResponseMetadata']['HTTPStatusCode'] != 200:
        raise Exception(f'Failed to save thumbnail {thumbnail_key}')

    return event
