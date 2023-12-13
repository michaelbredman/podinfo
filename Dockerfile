# Use an official Golang image as the base image
FROM golang:1.21-alpine as builder

# Set the working directory inside the container
WORKDIR /podinfo

# Copy only the go.mod and go.sum files to leverage Docker layer caching
COPY go.mod go.sum ./

# Download Go modules separately to leverage Docker layer caching
RUN go mod download

# Copy the rest of the source code
COPY . .

# Build the application with version information
ARG REVISION
RUN CGO_ENABLED=0 go build -ldflags "-s -w \
    -X github.com/stefanprodan/podinfo/pkg/version.REVISION=${REVISION}" \
    -a -o bin/podinfo cmd/podinfo/*

# Build the podcli application with version information
RUN CGO_ENABLED=0 go build -ldflags "-s -w \
    -X github.com/stefanprodan/podinfo/pkg/version.REVISION=${REVISION}" \
    -a -o bin/podcli cmd/podcli/*

# Start a new stage for the final image
FROM alpine:3.18

# Set build arguments
ARG BUILD_DATE
ARG VERSION
ARG REVISION

# Create a non-root user for running the application
RUN addgroup -S app && adduser -S -G app app

# Install necessary packages
RUN apk --no-cache add ca-certificates curl netcat-openbsd

# Set the working directory
WORKDIR /home/app

# Copy the built application from the builder stage
COPY --from=builder /podinfo/bin/podinfo .
COPY --from=builder /podinfo/bin/podcli /usr/local/bin/podcli
COPY ./ui ./ui

# Change ownership to the non-root user
RUN chown -R app:app ./

# Switch to the non-root user
USER app

# Define the command to run the application
CMD ["./podinfo"]
