
FROM node:18-alpine
WORKDIR /usr/src/app
COPY package*.json ./
COPY . .
RUN yarn install
RUN apk add --no-cache bash
RUN yarn build
RUN chmod +x replace_env.sh
CMD [ "/bin/bash", "-c", "/usr/src/app/replace_env.sh && yarn start-server" ]

