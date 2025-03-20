# Multi-platform Node 20 Alpine
FROM --platform=$BUILDPLATFORM node:20-alpine

# Add build essentials for compiling native modules
RUN apk add --no-cache make gcc g++ python3

WORKDIR /usr/src/app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install --ignore-scripts

# Copy the rest of the code
COPY . .

# Build ReScript first, then final build
RUN npm run re:build && npm run build

# Expose the port
EXPOSE 9050

# Development mode CMD
CMD ["sh", "-c", "npm run re:build && npm run start"]
