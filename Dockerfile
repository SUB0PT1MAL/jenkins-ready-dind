FROM docker:dind

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chown root:root /usr/local/bin/docker-entrypoint.sh
RUN chmod 700 /usr/local/bin/docker-entrypoint.sh
RUN apk update
RUN apk add openssh-server python3 git wget openrc openjdk17
RUN mkdir /run/openrc
RUN touch /run/openrc/softlevel
RUN rc-status
ENTRYPOINT ["dockerd-entrypoint.sh"]