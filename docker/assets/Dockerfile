FROM node:22-alpine
WORKDIR /src
COPY app/package*.json ./
RUN npm ci
COPY app/ ./
RUN npm run build
