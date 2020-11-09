FROM golang:1.15.2 as builder
WORKDIR /workspace

# Run this with docker build --build_arg $(go env GOPROXY) to override the goproxy
ARG goproxy=https://proxy.golang.org
ENV GOPROXY=$goproxy

# Copy the Go Modules manifests
COPY go.* .
# Cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

# Copy the sources
COPY ./ ./

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -a -ldflags '-extldflags "-static"' \
    -o server .

# Use the official Alpine image for a lean production container.
FROM alpine:3
RUN apk add --no-cache ca-certificates
WORKDIR /
COPY --from=builder /workspace/server .
ENTRYPOINT ["/server"]
