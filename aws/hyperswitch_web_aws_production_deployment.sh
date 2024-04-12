#!/bin/bash

command_discovery() {
    type $1 >/dev/null 2>/dev/null
    if [[ $? != 0 ]]; then
        echo "\`$1\` command not found"
        exit 1
    fi
}

command_discovery curl
command_discovery aws

echo "Installing Node Modules"

echo $( (npm install --force))
echo $( (npm run re:build))

echo "Starting AWS S3 Configurations"
echo "Please enter your AWS Region"
read AWS_REGION </dev/tty

if [ -z "$AWS_REGION" ]; then
    echo "Using us-east-2 by default"
    AWS_REGION="us-east-2"
fi
echo "Do you wish to create a new bucket on AWS S3? Ensure you have CreateBucket access on AWS (Y/N)"
read CREATE_BUCKET_BOOL </dev/tty

if [[ "$CREATE_BUCKET_BOOL" == "Y" ]] || [[ "$CREATE_BUCKET_BOOL" == "y" ]]; then
    echo "Creating a bucket on AWS"
    echo "Please enter a name for your bucket:"
    read MY_AWS_S3_BUCKET_NAME </dev/tty

    echo "Creating Bucket on AWS S3"
    export AWS_BUCKET_LOCATION=$(
        aws s3api create-bucket \
            --region $AWS_REGION \
            --bucket $MY_AWS_S3_BUCKET_NAME \
            --query 'Location' \
            --output text \
            --create-bucket-configuration LocationConstraint=$AWS_REGION
    )
    echo "Bucket created at the location: $AWS_BUCKET_LOCATION"
fi

echo "Building the distributable bundle for the application"
if [ -z "$AWS_BUCKET_LOCATION" ]; then
    echo "Enter the AWS S3 bucket location where you wish to store the Hyperswitch Client (my-bucket.s3.us-east-2.amazonaws.com)"
    read AWS_BUCKET_LOCATION </dev/tty
fi
echo "Setting bucket as public"
echo $( (
    aws s3api put-public-access-block \
        --bucket $MY_AWS_S3_BUCKET_NAME \
        --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"
))

echo "Adding bucket policy to make it public"

AWS_BUCKET_POLICY='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::'$MY_AWS_S3_BUCKET_NAME'/*"
    }
  ]
}'

echo "Displaying the policy to be added $AWS_BUCKET_POLICY"

echo $( (aws s3api put-bucket-policy --bucket $MY_AWS_S3_BUCKET_NAME --policy "$AWS_BUCKET_POLICY"))

echo "Bucket configuration updated"

echo "Enter the backend endpoint your Hyperswitch Client will hit (hosted Hyperswitch Backend, https://beta.hyperswitch.io/api is taken by default):"
read AWS_BACKEND_URL </dev/tty

if [ -z $AWS_BACKEND_URL ]; then
    echo "Setting backend URL value to https://beta.hyperswitch.io/api by default"
    AWS_BACKEND_URL="https://beta.hyperswitch.io/api"

fi

export envSdkUrl="${AWS_BUCKET_LOCATION%?}"
export envBackendUrl=$AWS_BACKEND_URL
npm run build

echo "Inititating file upload to S3"
echo "Enter the folder name you want to push the assets to"
read AWS_DESTINATION_KEY </dev/tty

echo "Uploading files to S3"
echo $( (aws s3 cp "./dist" "s3://$MY_AWS_S3_BUCKET_NAME/$AWS_DESTINATION_KEY" --recursive))
echo "Uploaded files "

echo "Hurray! You now have hosted your Hyperswitch Web to S3! You can use this URL for your integrations : $AWS_BUCKET_LOCATION$AWS_DESTINATION_KEY/HyperLoader.js"
