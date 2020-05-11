FROM alpine:3.11

ENV VAULT_VERSION 1.4.0

RUN mkdir -p /vault/config

RUN apk --no-cache add bash ca-certificates wget

RUN wget --quiet --output-document=/tmp/vault.zip https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip && \
    unzip /tmp/vault.zip -d /vault && \
    rm -f /tmp/vault.zip && \
    chmod +x /vault

ENV PATH="PATH=$PATH:$PWD/vault"

COPY start.sh /
COPY vault-mgr.sh /
COPY config/vault-config.json /vault/config/

EXPOSE 8200

ENTRYPOINT ["/start.sh"]
