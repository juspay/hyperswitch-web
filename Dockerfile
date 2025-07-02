# Use Node 20 with Alpine
FROM node:20-alpine

# Install build essentials + git (optional)
RUN apk add --no-cache make gcc g++ python3

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm install --ignore-scripts

# ✅ Do not run npm run setup:submodules — you already did it outside
# So just copy the full app code, including submodules
COPY . .

RUN npm run re:build && npm run build

EXPOSE 9050

CMD ["/bin/sh", "-c", "npm run re:build && npm run start"]
