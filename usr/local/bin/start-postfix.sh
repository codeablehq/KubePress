#!/bin/sh

trap "postfix stop" SIGINT
trap "postfix stop" SIGTERM
trap "postfix reload" SIGHUP

[ -n "${SMTP_DOMAIN}" ] && postconf mydomain=${SMTP_DOMAIN}
[ -n "${SMTP_HOSTNAME}" ] && postconf myhostname=${SMTP_HOSTNAME}

if [ -n "${SMTP_SERVER}" ]; then
  [ -z "${SMTP_USERNAME}" ] && echo "No SMTP_USERNAME is set!" && exit 2
  [ -z "${SMTP_PASSWORD}" ] && echo "No SMTP_PASSWORD is set!" && exit 2

  postconf relayhost=[${SMTP_SERVER}]:${SMTP_PORT:-587} \
    smtp_sasl_auth_enable=yes \
    smtp_use_tls=yes \
    smtp_sasl_password_maps=hash:/etc/postfix/sasl_passwd \
    smtp_sasl_security_options=noanonymous

  echo "[${SMTP_SERVER}]:${SMTP_PORT:-587} ${SMTP_USERNAME}:${SMTP_PASSWORD}" >> /etc/postfix/sasl_passwd

  postmap /etc/postfix/sasl_passwd
  rm /etc/postfix/sasl_passwd
  chmod 600 /etc/postfix/sasl_passwd.db
fi

# Start postfix
postfix -c /etc/postfix start

# Give it some more time to boot before checking whether it's live
sleep 5

# Infinitely (every 5 seconds) check whether postfix is running
# TODO: There must be a better way to do this, and "postfix status" isn't
# a good solution because it makes logs noisier
while true; do
  kill -0 $(cat /var/spool/postfix/pid/master.pid) > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    exit 1;
  fi
  sleep 5
done
