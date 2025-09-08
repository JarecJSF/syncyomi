# build web
FROM node:18.12.0-alpine3.16 AS web-builder
WORKDIR /web
COPY web/package.json web/pnpm-lock.yaml ./

# Instalar pnpm v7.13.4 (compatible con el lockfile existente)
RUN npm install -g pnpm@7.13.4

# CREAR .npmrc PARA IGNORAR ERRORES DE DEPENDENCIAS DE PARES
RUN echo "strict-peer-dependencies=false" > .npmrc

# Instalar dependencias ignorando problemas de peer dependencies
RUN pnpm install --prod
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

# Puerto correcto (SyncYomi usa 8080 por defecto)
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/syncyomi", "--config", "/config"]
