FROM debian:jessie
MAINTAINER Tomaz Zaman <tomaz@codeable.io>

# Set up some useful environment variables
ENV DEBIAN_FRONTEND noninteractive

ENV WP_ROOT /var/www/wordpress
ENV WP_VERSION 4.7.5
ENV WP_SHA1 fbe0ee1d9010265be200fe50b86f341587187302
ENV WP_DOWNLOAD_URL https://wordpress.org/wordpress-$WP_VERSION.tar.gz

RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    locales \
    runit \
    syslog-ng \
    && rm -rf /var/lib/apt/lists/*

ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen en_US.UTF-8

RUN echo "deb http://nginx.org/packages/debian/ jessie nginx" > \
      /etc/apt/sources.list.d/nginx.list \
    && echo "deb https://packages.sury.org/php/ jessie main" > \
      /etc/apt/sources.list.d/php.list \
    && curl -vs http://nginx.org/keys/nginx_signing.key | apt-key add - \
    && curl -o /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg

RUN apt-get update && apt-get install -y \
    nginx imagemagick \
    php7.1-fpm php7.1-mysqli php7.1-curl php7.1-gd php7.1-geoip php7.1-xml php7.1-xmlrpc \
    && rm -rf /var/lib/apt/lists/*

# Temporary, until Docker's built-in init becomes more wide-spread
ADD https://github.com/Yelp/dumb-init/releases/download/v1.2.0/dumb-init_1.2.0_amd64 /usr/bin/dumb-init
RUN chmod +x /usr/bin/dumb-init

# Since we want to be able to update WordPress seamlessly, we need to
# declare a volume that is mounted in place of the default wp-content, so
# we can swap WP versions and re-use the same wp-content
VOLUME /var/www/wordpress/wp-content
WORKDIR /var/www/wordpress/wp-content

# For convenience, set www-data to UID and GID 1000
RUN groupmod -g 1000 www-data && usermod -u 1000 www-data

# Download and extract WordPress into /var/www/wordpress
RUN curl -o wordpress.tar.gz -SL $WP_DOWNLOAD_URL \
    && echo "$WP_SHA1 *wordpress.tar.gz" | sha1sum -c - \
    && tar -xzf wordpress.tar.gz -C $(dirname $WP_ROOT) \
    && rm wordpress.tar.gz

# Create an empty directory in which we can mount secrets
VOLUME /etc/secrets

# Copy our custom wp-config.php over. This is arguably the most important
# part/trick, that makes WordPress container-friendly. Instead of hard-coding
# configuraion, we just loop through all environment variables and define
# them for use inside WordPress/PHP
COPY wp-config.php $WP_ROOT
RUN chown -R www-data:www-data $WP_ROOT \
    && chmod 640 $WP_ROOT/wp-config.php

COPY rootfs /

# We only expose port 80, but not 443. In a proper "containerized" manner
# HTTPS should be handled by a separate Nginx container/reverse proxy
EXPOSE 80

ENTRYPOINT ["/usr/bin/dumb-init", "--"]

CMD ["runsvdir", "-P", "/etc/service"]
