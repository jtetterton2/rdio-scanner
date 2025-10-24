################################################################################
# Multi-Stage Docker Build for Rdio Scanner
#
# Stage 1: Build Angular frontend
# Stage 2: Build Go backend
# Stage 3: Create minimal runtime image
#
# Benefits:
# - Smaller final image (~50MB vs hundreds of MB)
# - No build tools in production image (improved security)
# - Clear separation of build and runtime dependencies
# - Faster subsequent builds with layer caching
################################################################################

# Stage 1: Build Angular Frontend
FROM docker.io/node:18-alpine AS frontend-builder

LABEL stage=frontend-builder

WORKDIR /build/client

# Copy package files for dependency installation
COPY client/package*.json ./

# Install dependencies (with caching optimization)
RUN npm ci --loglevel=error --no-progress

# Copy source code
COPY client/ ./

# Create server directory for Angular output (outputPath is ../server/webapp)
RUN mkdir -p /build/server

# Build the Angular application
# Angular is configured to output to ../server/webapp
RUN npm run build

################################################################################

# Stage 2: Build Go Backend
FROM docker.io/golang:1.22-alpine AS backend-builder

LABEL stage=backend-builder

WORKDIR /build

# Copy Go source
COPY server/ ./

# Copy built frontend from previous stage
COPY --from=frontend-builder /build/server/webapp/ /build/webapp/

# Build the Go application
# CGO_ENABLED=0 creates a static binary for better portability
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o rdio-scanner

################################################################################

# Stage 3: Runtime Image
FROM docker.io/alpine:latest

LABEL maintainer="Chrystian Huot <chrystian.huot@saubeo.solutions>"
LABEL description="Rdio Scanner - Radio communications monitor"
LABEL version="6.6.3"

WORKDIR /app

# Set environment variable to indicate Docker environment
ENV DOCKER=1

# Install only runtime dependencies (no build tools)
# - ffmpeg: Audio processing
# - mailcap: MIME type support
# - tzdata: Timezone data
# - ca-certificates: SSL/TLS support
RUN apk --no-cache --no-progress add \
    ffmpeg \
    mailcap \
    tzdata \
    ca-certificates

# Create data directory for persistent storage
RUN mkdir -p /app/data

# Copy compiled binary from backend builder
COPY --from=backend-builder /build/rdio-scanner /app/

# Verify binary is executable
RUN chmod +x /app/rdio-scanner

# Expose application port
EXPOSE 3000

# Define volume for persistent data
VOLUME ["/app/data"]

# Run as non-root user for security (optional - uncomment to enable)
# RUN adduser -D -u 1000 rdio && chown -R rdio:rdio /app
# USER rdio

# Start the application
ENTRYPOINT ["./rdio-scanner", "-base_dir", "/app/data"]
