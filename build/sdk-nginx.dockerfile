FROM node:18 as build_stage

# npm sdk build configuration
ARG SDK_URL
ARG BACKEND_URL
ARG HYPERSWITCH_VERSION
ARG ENV

RUN \
  : "${SDK_URL:?SDK_URL build argument is required and must not be empty}" && \
  : "${BACKEND_URL:?BACKEND_URL build argument is required and must not be empty}" && \
  : "${HYPERSWITCH_VERSION:?HYPERSWITCH_VERSION build argument is required and must not be empty}" && \
  : "${ENV:?ENV build argument is required and must not be empty}"

WORKDIR /app

RUN git clone --branch v${HYPERSWITCH_VERSION} https://github.com/juspay/hyperswitch-web /app
RUN npm install
RUN npm run re:build
RUN envSdkUrl=${SDK_URL} envBackendUrl=${BACKEND_URL} npm run build:${ENV}


FROM nginx:1.25.3 as run

ARG HYPERSWITCH_VERSION
ARG EXTRA_PATH
ENV NGINX_LOCATION_PATH=/${HYPERSWITCH_VERSION}/${EXTRA_PATH}

RUN rm /etc/nginx/conf.d/default.conf

COPY nginx.conf.template /etc/nginx/conf.d/nginx.conf.template

RUN envsubst '${NGINX_LOCATION_PATH}' < /etc/nginx/conf.d/nginx.conf.template > /etc/nginx/conf.d/default.conf

COPY --from=build_stage /app/dist/${ENV}/*  /usr/share/nginx/html/${NGINX_LOCATION_PATH}

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
