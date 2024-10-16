FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y wget unzip git && \
    wget https://storage.googleapis.com/download/flutter_macos_3.0.0-stable.zip && \
    unzip flutter_macos_3.0.0-stable.zip -d /opt && \
    rm flutter_macos_3.0.0-stable.zip && \
    export PATH="/opt/flutter/bin:$PATH"

WORKDIR /workspace
