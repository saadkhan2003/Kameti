# Stage 1: Build the Flutter web app
FROM ghcr.io/cirruslabs/flutter:stable AS build

# Set working directory
WORKDIR /app

# Copy pubspec files first for better caching
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy the rest of the application
COPY . .

# Build the web application
RUN flutter build web --release

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copy the build output to nginx html directory
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy custom nginx configuration for SPA routing
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 3000 (for Coolify)
EXPOSE 3000

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
