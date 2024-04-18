#!/bin/bash

command_discovery() {
  type $1 > /dev/null 2> /dev/null
  if [[ $? != 0 ]]; then
    echo "\`$1\` command not found"
    exit 1
  fi
}

command_discovery curl
command_discovery aws

echo "Please enter the URL where you have hosted Hyperswitch Backend (https://beta.hyperswitch.io/api) "
read HYPERSWITCH_SERVER_URL < /dev/tty

if [ -z "$HYPERSWITCH_SERVER_URL" ]; then
    echo "Using default api url: https://beta.hyperswitch.io/api"
    HYPERSWITCH_SERVER_URL="https://beta.hyperswitch.io/api"
fi

# echo "Please enter the api url (https://beta.hyperswitch.io/api) "
# read apiBaseUrl < /dev/tty

# if [ -z "$apiBaseUrl" ]; then
#     echo "Using default api url: https://beta.hyperswitch.io/api"
#     apiBaseUrl="https://beta.hyperswitch.io/api"
# fi

echo "Please enter the URL where you have hosted Hyperswitch Client SDK (https://beta.hyperswitch.io/v1) "
read HYPERSWITCH_CLIENT_URL < /dev/tty

if [ -z "$HYPERSWITCH_CLIENT_URL" ]; then
    echo "Using default api url: https://beta.hyperswitch.io/v1"
    HYPERSWITCH_CLIENT_URL="https://beta.hyperswitch.io/v1"
fi

echo "Please enter the Publishable Key for your account (pk_*************). Can be found in Hyperswitch Control Center.(https://app.hyperswitch.io) "
read PUBLISHABLE_KEY < /dev/tty

if [ -z "$PUBLISHABLE_KEY" ]; then
    echo "Cannot proceed without a Publishable Key, please create a merchant account to generate a Publishable Key via Hyperswitch API or Control Center"
    exit 1
fi

echo "Please enter the Secret Key for your account (snd_*************). Can be found in Hyperswitch Control Center.(https://app.hyperswitch.io) "
read SECRET_KEY < /dev/tty

if [ -z "$SECRET_KEY" ]; then
    echo "Cannot proceed without a Secret Key, please create a merchant account to generate a Secret Key via Hyperswitch API or Control Center"
    exit 1
fi



echo "Please enter the AWS region (us-east-2): "
read REGION < /dev/tty

if [ -z "$REGION" ]; then
    echo "Using default region: us-east-2"
    REGION="us-east-2"
fi




#############  APPLICATION ##################
# CREATE SECURITY GROUP FOR APPLICATION

echo "Creating Security Group for Application..."

export EC2_SG="application-sg"

echo `(aws ec2 create-security-group \
--region $REGION \
--group-name $EC2_SG \
--description "Security Group for Hyperswitch EC2 instance" \
--tag-specifications "ResourceType=security-group,Tags=[{Key=ManagedBy,Value=hyperswitch-web}]" \
)`

export APP_SG_ID=$(aws ec2 describe-security-groups --group-names $EC2_SG --region $REGION --output text --query 'SecurityGroups[0].GroupId')

echo "Security Group for Application CREATED.\n"

echo "Creating Security Group ingress for port 80..."

echo `aws ec2 authorize-security-group-ingress \
--group-id $APP_SG_ID \
--protocol tcp \
--port 80 \
--cidr 0.0.0.0/0 \
--region $REGION`

echo "Security Group ingress for port 80 CREATED.\n"


echo "Creating Security Group ingress for port 22..."

echo `aws ec2 authorize-security-group-ingress \
--group-id $APP_SG_ID \
--protocol tcp \
--port 22 \
--cidr 0.0.0.0/0 \
--region $REGION`

echo "Security Group ingress for port 22 CREATED.\n"

cat << EOF > user_data.sh
#!/bin/bash

sudo yum update -y
sudo amazon-linux-extras install docker
sudo service docker start
sudo usermod -a -G docker ec2-user

docker pull juspaydotin/hyperswitch-web:v1.0.0

docker run -p 80:5252 -e HYPERSWITCH_SERVER_URL=${HYPERSWITCH_SERVER_URL} -e SELF_SERVER_URL=http://localhost:9000/ -e HYPERSWITCH_CLIENT_URL=${HYPERSWITCH_CLIENT_URL} -e HYPERSWITCH_PUBLISHABLE_KEY=${PUBLISHABLE_KEY} -e HYPERSWITCH_SECRET_KEY=${SECRET_KEY}  juspaydotin/hyperswitch-web:v1.0.0 

EOF

# echo "docker run -p 80:9000 -e apiBaseUrl=${apiBaseUrl} -e sdkBaseUrl=${sdkBaseUrl} juspaydotin/hyperswitch-control-center:v1.0.0" >> user_data.sh

export AWS_AMI_ID=$(aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-2.0.*" --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text --region $REGION)

echo "AWS AMI ID retrieved.\n"

echo "Creating EC2 Keypair..."

rm -rf hyperswitch-keypair.pem

aws ec2 create-key-pair \
    --key-name hyperswitch-ec2-keypair \
    --query 'KeyMaterial' \
    --tag-specifications "ResourceType=key-pair,Tags=[{Key=ManagedBy,Value=hyperswitch-web}]" \
    --region $REGION \
    --output text > hyperswitch-keypair.pem

echo "Keypair created and saved to hyperswitch-keypair.pem.\n"

chmod 400 hyperswitch-keypair.pem

echo "Launching EC2 Instance..."

export HYPERSWITCH_INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AWS_AMI_ID \
    --instance-type t3.medium \
    --key-name hyperswitch-ec2-keypair \
    --monitoring "Enabled=false" \
    --security-group-ids $APP_SG_ID \
    --user-data file://./user_data.sh \
    --query 'Instances[0].InstanceId' \
    --output text \
    --region $REGION)

echo "EC2 instance launched.\n"

echo "Add Tags to EC2 instance..."

echo `aws ec2 create-tags \
--resources $HYPERSWITCH_INSTANCE_ID \
--tags "Key=Name,Value=hyperswitch-web" \
--region $REGION`

echo "Tag added to EC2 instance.\n"

echo `aws ec2 create-tags \
--resources $HYPERSWITCH_INSTANCE_ID \
--tags "Key=ManagedBy,Value=hyperswitch-web" \
--region $REGION`

echo "ManagedBy tag added to EC2 instance.\n"


echo "Retrieving the Public IP of Hyperswitch EC2 Instance..."
export PUBLIC_HYPERSWITCH_IP=$(aws ec2 describe-instances \
--instance-ids $HYPERSWITCH_INSTANCE_ID \
--query "Reservations[*].Instances[*].PublicIpAddress" \
--output=text \
--region $REGION)

echo "Hurray! You can try using Hyperswitch Web Client at http://$PUBLIC_HYPERSWITCH_IP"