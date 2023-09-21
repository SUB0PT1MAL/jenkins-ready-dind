#!/bin/sh
set -eu

# hijacking entrypoint to start ssh server and configuration, login to docker registry and adding the user with custom password "extremely dirty, I know"
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
service sshd restart
echo 'root:'$SSH_JENKINS_PASSWD | chpasswd
export SSH_JENKINS_PASSWD="nope"
docker login --username=$DOCKER_USER --password=$DOCKER_PASS $DOCKER_HOST
export DOCKER_USER="nope"
export DOCKER_PASS="nope"
export DOCKER_HOST="nope"

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- docker "$@"
fi

# if our command is a valid Docker subcommand, let's invoke it through Docker instead
# (this allows for "docker run docker ps", etc)
if docker help "$1" > /dev/null 2>&1; then
	set -- docker "$@"
fi

_should_tls() {
	[ -n "${DOCKER_TLS_CERTDIR:-}" ] \
	&& [ -s "$DOCKER_TLS_CERTDIR/client/ca.pem" ] \
	&& [ -s "$DOCKER_TLS_CERTDIR/client/cert.pem" ] \
	&& [ -s "$DOCKER_TLS_CERTDIR/client/key.pem" ]
}

# if we have no DOCKER_HOST but we do have the default Unix socket (standard or rootless), use it explicitly
if [ -z "${DOCKER_HOST:-}" ] && [ -S /var/run/docker.sock ]; then
	export DOCKER_HOST=unix:///var/run/docker.sock
elif [ -z "${DOCKER_HOST:-}" ] && XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" && [ -S "$XDG_RUNTIME_DIR/docker.sock" ]; then
	export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"
fi

# if DOCKER_HOST isn't set (no custom setting, no default socket), let's set it to a sane remote value
if [ -z "${DOCKER_HOST:-}" ]; then
	if _should_tls || [ -n "${DOCKER_TLS_VERIFY:-}" ]; then
		export DOCKER_HOST='tcp://docker:2376'
	else
		export DOCKER_HOST='tcp://docker:2375'
	fi
fi
if [ "${DOCKER_HOST#tcp:}" != "$DOCKER_HOST" ] \
	&& [ -z "${DOCKER_TLS_VERIFY:-}" ] \
	&& [ -z "${DOCKER_CERT_PATH:-}" ] \
	&& _should_tls \
; then
	export DOCKER_TLS_VERIFY=1
	export DOCKER_CERT_PATH="$DOCKER_TLS_CERTDIR/client"
fi

if [ "$1" = 'dockerd' ]; then
	cat >&2 <<-'EOW'

		📎 Hey there!  It looks like you're trying to run a Docker daemon.

		   You probably should use the "dind" image variant instead, something like:

		     docker run --privileged --name some-docker ... docker:dind ...

		   See https://hub.docker.com/_/docker/ for more documentation and usage examples.

	EOW
	sleep 3
fi

exec "$@"
