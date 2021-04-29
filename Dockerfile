FROM debian:stable-slim

RUN apt-get update && apt-get install -y \
curl

WORKDIR /app
ADD . /app

CMD /bin/bash
