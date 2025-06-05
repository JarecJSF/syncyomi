# Etapa de construcción
FROM node:18-alpine AS web-builder

WORKDIR /app/web
COPY web/package.json web/pnpm-lock.yaml ./
RUN npm install -g pnpm && pnpm install
COPY web/ ./
RUN pnpm build

# Etapa de construcción Go
FROM golang:1.21-alpine AS go-builder

# Instalar dependencias
RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /app

# Copiar archivos go
COPY go.mod go.sum ./
RUN go mod download

# Copiar código fuente
COPY . .

# Copiar build web
COPY --from=web-builder /app/web/dist ./web/dist

# Variables de build
ARG VERSION=latest
ARG REVISION=unknown
ARG BUILDTIME=unknown

# Construir la aplicación (usando main.go en la raíz)
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags "-s -w -X main.version=${VERSION} -X main.commit=${REVISION} -X main.date=${BUILDTIME}" \
    -o syncyomi \
    main.go

# Etapa final
FROM alpine:latest

# Instalar certificados SSL y timezone
RUN apk --no-cache add ca-certificates tzdata

# Crear usuario no-root
RUN adduser -D -s /bin/sh syncyomi

# Crear directorios necesarios
RUN mkdir -p /config /tmp
RUN chown -R syncyomi:syncyomi /config /tmp

# Cambiar a usuario no-root
USER syncyomi

WORKDIR /app

# Copiar binario desde etapa de construcción
COPY --from=go-builder /app/syncyomi .

# Exponer puerto
EXPOSE 8282

# Configurar punto de entrada
ENTRYPOINT ["./syncyomi"]
