FROM node:20-alpine

# Set the working directory
WORKDIR /usr/src/app

# Copy package.json and package-lock.json to install dependencies
COPY package*.json ./

# Install dependencies
RUN npm install --ignore-scripts

# Copy the rest of the application code
COPY . .

# Build the rescript code
RUN npm run re:build

# Build the application
RUN npm run build

# Expose the port that the Webpack dev server will run on
EXPOSE 9050

# Start the Webpack dev server
CMD ["npm", "run", "start"]
