FROM node:18 as base
WORKDIR /usr/src/web_demo

COPY . .

#WORKDIR /usr/src/web_demo/Hyperswitch-React-Demo-App
RUN yarn install
RUN node promptScript.js
RUN yarn build

EXPOSE 5252

CMD ["node", "dist/server.js"]



FROM nginx:alpine

RUN rm -rf /usr/share/nginx/html/*

COPY --from=base /usr/src/web_demo/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 5060

CMD ["nginx", "-g", "daemon off;"]
