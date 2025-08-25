# Use Node 20 with Alpine
FROM node:20-alpine

# Install build essentials + git + bash
RUN apk add --no-cache make gcc g++ python3 bash git

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm install --ignore-scripts

# Copy the full app code
COPY . .

# Initialize and update submodules
RUN git submodule update --init --recursive

RUN npm run re:build && npm run build

EXPOSE 9050

CMD ["/bin/sh", "-c", "npm run re:build && npm run start"]
