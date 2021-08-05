FROM debian:latest

RUN apt update && apt install -y vim git

RUN mkdir -p /app/templates

WORKDIR /app

COPY ./.templates/ /app/.templates/

COPY setup.sh  /app/

RUN chmod +x setup.sh

CMD ["/bin/bash"]
