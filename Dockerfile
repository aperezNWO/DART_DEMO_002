# --- Stage 1: Build ---
FROM dart:stable AS build

WORKDIR /app

# Copy pubspec files first to leverage Docker layer caching
COPY pubspec.yaml pubspec.lock ./

# RUN fresh pub get in the Linux container to download Linux binaries
RUN dart pub get

# Now copy the rest of the application source code
COPY . .

# Ensure dependencies are available and generate any necessary code
RUN dart pub get --offline

# Compile the server to an AOT executable for production performance
# Output is named 'server' (without .dart extension)
RUN dart compile exe bin/server.dart -o bin/server


# --- Stage 2: Runtime ---
# Use a minimal, secure Debian image to run the compiled binary
FROM debian:bullseye-slim

# Create a non-root user for security best practices
RUN useradd --system --create-home appuser \
  && mkdir --parents /app \
  && chown --recursive appuser:appuser /app
WORKDIR /app

# Copy the compiled executable from the build stage
COPY --from=build --chown=appuser:appuser /app/bin/server /app/server

# Expose the port the server listens on
EXPOSE 8080

# Run the server as the non-root user
USER appuser
CMD ["./server"]