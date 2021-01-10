FROM alpine

RUN apk add --no-cache bash socat jq curl python3 docker py3-pip \
    && rm -rf /var/cache/apk/*

RUN pip3 install --upgrade pip \
    && pip3 install awscli

# Install proxy scripts
RUN mkdir -p /run
COPY *.sh /run/
RUN chmod +x /run/*.sh

ENTRYPOINT [ "/run/proxy.sh" ]