
FROM node:18-alpine
WORKDIR /usr/src/app
COPY package*.json ./
COPY . .
RUN yarn install
RUN yarn build
CMD [  "yarn" ,"start-server" ]

