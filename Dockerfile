# Etapa de construcción
FROM golang:1.21-alpine AS builder

# Instalar dependencias necesarias
RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /app

# Copiar archivos de dependencias
COPY go.mod go.sum ./
RUN go mod download

# Copiar código fuente
COPY . .

# Construir la aplicación
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags '-extldflags "-static"' -o syncyomi ./cmd/syncyomi

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
COPY --from=builder /app/syncyomi .

# Exponer puerto
EXPOSE 8282

# Configurar punto de entrada
ENTRYPOINT ["./syncyomi"]
CMD ["--config=/config"]
