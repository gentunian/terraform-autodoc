FROM golang:alpine as builder
RUN apk add --update --no-cache curl jq git && mkdir /build
ADD autogen.sh /build/
WORKDIR /build
RUN ./autogen.sh && go get -v -d ./... && CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags '-extldflags "-static"' -o main .
FROM scratch
COPY --from=builder /build/main /app/
WORKDIR /app
CMD ["./main"]
