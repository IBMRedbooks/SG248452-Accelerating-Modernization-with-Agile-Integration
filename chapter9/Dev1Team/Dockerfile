FROM myorg-mq:latest
USER root
RUN useradd dev1app -G mqclient \
  && echo dev1app:passw0rd | chpasswd
USER mqm
COPY 30-Dev1Team.mqsc /etc/mqm/
