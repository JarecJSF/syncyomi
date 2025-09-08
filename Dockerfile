# build web
FROM node:18.12.0-alpine3.16 AS web-builder
WORKDIR /web
COPY web/package.json web/pnpm-lock.yaml ./

# Instalar pnpm fijando su versión (compatible con Node 18.12)
RUN npm install -g pnpm@8.8.1

# Instalar dependencias y construir el frontend
RUN pnpm install --frozen-lockfile --prod
COPY web/ .
RUN pnpm run build

# build app
FROM golang:1.20-alpine3.16 AS app-builder

ARG VERSION=dev
ARG REVISION=dev
ARG BUILDTIME

RUN apk add --no-cache git make build-base tzdata

ENV SERVICE=syncyomi

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . ./

# Copiar assets del frontend compilado
COPY --from=web-builder /web/dist ./web/dist
COPY --from=web-builder /web/build.go ./web

# Compilar la aplicación
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags "-s -w -X main.version=${VERSION} -X main.commit=${REVISION} -X main.date=${BUILDTIME}" \
    -o bin/syncyomi main.go

# build final image
FROM alpine:latest

LABEL org.opencontainers.image.source="https://github.com/syncyomi/syncyomi"

ENV HOME="/config" \
    XDG_CONFIG_HOME="/config" \
    XDG_DATA_HOME="/config"

RUN apk add --no-cache ca-certificates curl tzdata jq

WORKDIR /app

VOLUME /config

# Copiar binario compilado
COPY --from=app-builder /src/bin/syncyomi /usr/local/bin/

# Exponer puerto 8080 (corrección desde 8282)
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/syncyomi", "--config", "/config"]
