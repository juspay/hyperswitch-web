FROM node:18 as base
WORKDIR /usr/src/web

COPY . .

RUN yarn install
RUN yarn re:start
RUN yarn build:prod



FROM nginx:alpine

RUN rm -rf /usr/share/nginx/html/*

COPY --from=base /usr/src/web/dist/prod /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 9050

CMD ["nginx", "-g", "daemon off;"]
