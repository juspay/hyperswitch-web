FROM node:20-alpine

# Add build essentials
RUN apk add --no-cache make gcc g++ python3

WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --ignore-scripts

# Copy the rest of the application code
COPY . .

# First, build ReScript code and wait for it to complete
RUN npm run re:build && \
    # Then build the application with webpack
    npm run build

EXPOSE 9050

# For development, use a start script that ensures ReScript watch mode
# runs before starting webpack dev server
CMD npm run re:build && npm run start