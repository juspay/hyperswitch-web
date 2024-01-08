ARG SDK_NODE_VERSION
FROM node:${SDK_NODE_VERSION} as build_stage

ARG HYPERSWITCH_REPO
ARG HYPERSWITCH_VERSION

ARG SDK_URL
ARG SDK_BACKEND_URL
ARG SDK_BUILD_ENV

RUN \
  : "${HYPERSWITCH_REPO:?HYPERSWITCH_REPO build argument is required and must not be empty}" && \
  : "${HYPERSWITCH_VERSION:?HYPERSWITCH_VERSION build argument is required and must not be empty}" && \
  : "${SDK_URL:?SDK_URL build argument is required and must not be empty}" && \
  : "${SDK_BACKEND_URL:?SDK_BACKEND_URL build argument is required and must not be empty}" && \
  : "${SDK_BUILD_ENV:?SDK_BUILD_ENV build argument is required and must not be empty}"

WORKDIR /app

RUN git clone --branch v${HYPERSWITCH_VERSION} ${HYPERSWITCH_REPO} /app

RUN npm install
RUN npm run re:build
RUN envSdkUrl=${SDK_URL} envBackendUrl=${SDK_BACKEND_URL} npm run build:${SDK_BUILD_ENV}


FROM amazon/aws-cli as publisher

# sdk dist configuration
ARG SDK_URL
ARG HYPERSWITCH_VERSION
ARG AWS_CREATE_BUCKET
ARG AWS_DEFAULT_REGION
ARG AWS_DIST_S3_BUCKET
ARG AWS_S3_EXTRA_PREFIX

# Set default AWS env var in this stage
ENV AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ENV AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
ENV AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
ENV AWS_DIST_S3_BUCKET=${AWS_DIST_S3_BUCKET}

RUN \
  : "${SDK_URL:?SDK_URL build argument is required and must not be empty}" && \
  : "${HYPERSWITCH_VERSION:?HYPERSWITCH_VERSION build argument is required and must not be empty}" && \
  : "${AWS_CREATE_BUCKET:?AWS_CREATE_BUCKET build argument is required and must not be empty}" && \
  : "${AWS_DEFAULT_REGION:?AWS_DEFAULT_REGION build argument is required and must not be empty}" && \
  : "${AWS_DIST_S3_BUCKET:?AWS_DIST_S3_BUCKET build argument is required and must not be empty}" && \
  : "${AWS_S3_EXTRA_PREFIX:?AWS_S3_EXTRA_PREFIX build argument is required and must not be empty}"

WORKDIR /app

# Copy statics assets from previous node build
COPY --from=build_stage /app/dist/${SDK_BUILD_ENV}/*  .

# AWS bucket creation
RUN if [ "$AWS_CREATE_BUCKET" = "true" ]; then \
      if ! aws s3 ls "s3://${AWS_DIST_S3_BUCKET}" --region ${AWS_DEFAULT_REGION}; then \
        aws s3api create-bucket \
          --bucket ${AWS_DIST_S3_BUCKET} \
          --region ${AWS_DEFAULT_REGION} \
          --create-bucket-configuration \
          LocationConstraint=${AWS_DEFAULT_REGION} ; \
      fi \
    fi

# AWS publish sdk
RUN aws s3api put-public-access-block --bucket ${AWS_DIST_S3_BUCKET} --region ${AWS_DEFAULT_REGION} \
    --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

RUN  aws s3 cp  \
     --recursive  \
     ${PWD} s3://${AWS_DIST_S3_BUCKET}/${HYPERSWITCH_VERSION}/${AWS_S3_EXTRA_PREFIX}

# AWS Generate public access policy for AWS_DIST_S3_BUCKET
RUN echo '{ \
  "Version": "2012-10-17", \
  "Statement": [ \
    { \
      "Effect": "Allow", \
      "Principal": "*", \
      "Action": "s3:GetObject", \
      "Resource": "arn:aws:s3:::'"${AWS_DIST_S3_BUCKET}"'/*" \
    } \
  ] \
}' > /tmp/public-policy.json

# AWS Apply policy
RUN aws s3api put-bucket-policy --bucket ${AWS_DIST_S3_BUCKET} --policy file:///tmp/public-policy.json

# Ensure HyperLoader.js can be rechead from public
RUN echo "Ensure HyperLoader.js is available" && \
    curl ${SDK_URL}/${HYPERSWITCH_VERSION}/${AWS_S3_EXTRA_PREFIX}/HyperLoader.js

# Remove secret env
ENV AWS_ACCESS_KEY_ID=""
ENV AWS_SECRET_ACCESS_KEY=""
