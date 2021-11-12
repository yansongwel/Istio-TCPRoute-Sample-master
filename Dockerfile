FROM golang:latest AS builder   #不能使用最新的go编译要使用1.11之前的版本

RUN mkdir -p /go/src/github.com/osswangxining/go-echo
COPY . /go/src/github.com/osswangxining/go-echo

RUN go get ...
RUN CGO_ENABLED=0 go build -a -installsuffix cgo -o /go/bin/tcp-echo ./src/github.com/osswangxining/go-echo

FROM alpine:latest
RUN apk --no-cache add ca-certificates

COPY --from=builder /go/bin/tcp-echo /tcp-echo

WORKDIR /

ENTRYPOINT ["/tcp-echo"]
