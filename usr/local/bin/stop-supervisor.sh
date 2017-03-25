#!/bin/sh

# Supervisor loads this file and runs it as a service that listens
# to events coming in through /dev/stdin. Whenever any of the
# "erroneus" events come in (see supervisord.conf under [eventlistener])
# This script kills Supervisor itself, because it's Docker's
# responsibility to the kill the container (and spawn a new one in
# case of Kubernetes)


# We need this message to let Supervisor know this script is running
printf "READY\n";

PID=$(cat "/var/run/supervisord.pid");

# Wait infinitely for events from /dev/stdin. Kill Supervisor when they occur
while read line; do
  echo "Incoming Supervisor event: $line" >&2
  kill -SIGTERM $PID
done < /dev/stdin
