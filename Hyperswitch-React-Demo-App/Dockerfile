# Stage 1: Install dependencies & build client + server
FROM node:20 AS builder

WORKDIR /app

# Copy package files first for better caching
COPY package*.json ./

# Install dependencies with explicit React installation
RUN npm install
# Ensure react and its JSX runtime are properly installed
RUN npm install react react-dom --save

# Copy the rest of the application
COPY . .

# Build the frontend (client) assets
RUN npm run build

# Stage 2: Production-ready image
FROM node:20-slim

WORKDIR /app

# Copy necessary files from builder
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/server.js ./server.js
COPY --from=builder /app/package.json ./package.json

# Copy the src directory
COPY --from=builder /app/src ./src

# Copy public directory
COPY --from=builder /app/public ./public

# Copy webpack config files
COPY --from=builder /app/webpack.*.js ./

# Install server dependencies
RUN npm install node-fetch dotenv concurrently

# Default port env (can be overridden)
ENV PORT=5252
ENV CLIENT_PORT=9060

# Expose both server and client ports
EXPOSE 5252
EXPOSE 9060

# Start server and client concurrently
CMD ["sh", "-c", "npm run start"]