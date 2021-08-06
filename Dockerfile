FROM debian:latest

RUN apt update && apt install -y vim git

RUN mkdir -p /app /tests

VOLUME ["/app"]

WORKDIR /tests

CMD  /bin/bash
