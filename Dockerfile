FROM node:18 as base

WORKDIR /usr/src/web
COPY . .

RUN yarn install

RUN rm -rf node_modules Hyperswitch-React-Demo-App/node_modules

FROM node:18-alpine

WORKDIR /usr/src/web

COPY --from=base /usr/src/web/ ./

EXPOSE 8080 9050 9060 5252 4242

CMD ["yarn", "start:dev"]
CMD ["yarn", "start:playground"]