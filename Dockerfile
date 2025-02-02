# Use an official Node.js image as the base image
Checking latest version for node:18-alpine...
✅ Updating node:18-alpine → node
FROM node

# Set the working directory inside the container
WORKDIR /app

# Copy package.json and package-lock.json files
COPY package.json package-lock.json ./

# Install the dependencies
RUN npm install

# Copy the rest of the application files
COPY . .

# Expose a port (optional, for web apps)
EXPOSE 3000

# Set the default command to start the app
CMD ["npm", "start"]
