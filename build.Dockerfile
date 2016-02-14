FROM ubuntu:14.04
MAINTAINER Microfactory <info@microfactory.io>
RUN apt-get update; apt-get install -y curl unzip git ;

# install golang runtime
RUN curl -L https://storage.googleapis.com/golang/go1.5.2.linux-amd64.tar.gz > /tmp/golang.tar.gz; tar -C /usr/local -xzf /tmp/golang.tar.gz; rm /tmp/golang.tar.gz
ENV GOPATH=/ GO15VENDOREXPERIMENT=1 PATH=$PATH:/usr/local/go/bin
WORKDIR /src/github.com/microfactory/zero
CMD GO15VENDOREXPERIMENT=1 go build -ldflags="-X main.version=`cat VERSION`" -o ./linux-amd64/zero main.go
