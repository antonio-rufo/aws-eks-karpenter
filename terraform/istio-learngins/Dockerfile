FROM envoyproxy/envoy:v1.34.0
RUN apt-get update
COPY config.yaml /etc/envoy.yaml
CMD /usr/local/bin/envoy -c /etc/envoy.yaml