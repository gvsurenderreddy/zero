FROM ubuntu:14.04
MAINTAINER Microfactory <info@microfactory.io>
RUN apt-get update; apt-get install -y curl unzip;

# install golang runtime
RUN curl -L https://storage.googleapis.com/golang/go1.5.2.linux-amd64.tar.gz > /tmp/golang.tar.gz; tar -C /usr/local -xzf /tmp/golang.tar.gz; rm /tmp/golang.tar.gz

#zerotier
RUN curl -L https://download.zerotier.com/dist/zerotier-one_1.1.2_amd64.deb > /tmp/ztier.deb; dpkg -i /tmp/ztier.deb; rm /tmp/ztier.deb

# #setup go env
ENV GOPATH=/ GO15VENDOREXPERIMENT=1 PATH=$PATH:/usr/local/go/bin
ADD . /src/github.com/microfactory/zero
WORKDIR /src/github.com/microfactory/zero
RUN go build -ldflags="-X main.Version=`cat VERSION`" -o /usr/local/bin/zero main.go
ENTRYPOINT ["zero"]
