FROM golang:alpine as builder
# Install make and certificates
RUN apk --no-cache add tzdata zip ca-certificates make git
# Make repository path
RUN mkdir -p /go/src/github.com/josh9398/simple-server
WORKDIR /go/src/github.com/josh9398/simple-server
# Copy all project files
ADD . .
# Install deps
RUN make deps
# Generate a binary
RUN make bin

# Second (final) stage, base image is scratch
FROM scratch
# Copy statically linked binary
COPY --from=builder /go/src/github.com/josh9398/simple-server/bin/simple-server /simple-server
# Copy SSL certificates
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
# Notice "CMD", we don't use "Entrypoint" because there is no OS
CMD [ "/simple-server" ]