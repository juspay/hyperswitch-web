# Use Node 20 with Alpine
FROM node:20-alpine

# Install build essentials + git (for submodules)
RUN apk add --no-cache make gcc g++ python3 git

# Set working dir
WORKDIR /usr/src/app

# Copy only package files first — enables Docker cache
COPY package*.json ./

# Install dependencies WITHOUT postinstall (so playground install is skipped)
RUN npm install --ignore-scripts

# Pull required submodules manually — this ensures `shared-code` exists
RUN npm run setup:submodules

# Copy the rest of the source code
COPY . .

# Compile ReScript & then bundle with Webpack
RUN npm run re:build && npm run build

# Expose your desired port
EXPOSE 9050

# Default container start command
CMD npm run re:build && npm run start
