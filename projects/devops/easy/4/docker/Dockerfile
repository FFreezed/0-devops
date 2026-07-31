# Stage 1
FROM ubuntu:24.04 AS builder

RUN apt-get update && apt-get install -y sed

WORKDIR /app

RUN echo '<h1>Welcome to Devops Staging Environment</h1>' > raw_index.html

RUN sed 's/Devops/DEVOPS/g' raw_index.html > index.html

# Stage 2
FROM nginx:alpine

COPY --from=builder /app/index.html /usr/share/nginx/html/index.html
