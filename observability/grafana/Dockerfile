FROM grafana/grafana:13.2.2

USER root

RUN apk upgrade --no-cache

COPY provisioning/ /etc/grafana/provisioning/

USER 472
