FROM php:7.1.3-fpm-alpine
MAINTAINER Tomaz Zaman <tomaz@codeable.io>

# Install necessary system dependencies
RUN apk add --no-cache \
    bash \
    curl-dev \
    imagemagick \
    libpng-dev \
    libxml2-dev \
    nginx \
    openssl \
    redis \
    supervisor

# Set up some useful environment variables
ENV WP_ROOT /var/www/wordpress
ENV WP_VERSION 4.7.3
ENV WP_SHA1 35adcd8162eae00d5bc37f35344fdc06b22ffc98
ENV WP_DOWNLOAD_URL https://wordpress.org/wordpress-$WP_VERSION.tar.gz

# Since we want to be able to update WordPress seamlessly, we need to
# declare a volume that is mounted in place of the default wp-content, so
# we can swap WP versions and re-use the same wp-content
VOLUME /var/www/wordpress/wp-content
WORKDIR /var/www/wordpress/wp-content

# Install the necessary php libraries and extensions to run the most common
# WordPress plugins and functionality (like image manipulation with ImageMagick)
RUN apk add --no-cache libtool build-base autoconf imagemagick-dev \
    && export CFLAGS="-I/usr/src/php" \
    && docker-php-ext-install \
      -j$(grep -c ^processor /proc/cpuinfo 2>/dev/null) \
      # Extensions missing from this list are already compiled in by default
      # http://wordpress.stackexchange.com/questions/42098
      gd mbstring xmlreader xmlwriter ftp mysqli opcache sockets \
    && pecl install imagick \
    && docker-php-ext-enable imagick \
    && apk del libtool build-base autoconf imagemagick-dev

# Download and extract WordPress into /var/www/wordpress
RUN curl -o wordpress.tar.gz -SL $WP_DOWNLOAD_URL \
    && echo "$WP_SHA1 *wordpress.tar.gz" | sha1sum -c - \
    && tar -xzf wordpress.tar.gz -C $(dirname $WP_ROOT) \
    && rm wordpress.tar.gz

RUN adduser -D wordpress -s /bin/bash -G www-data

# For convenience, install wp-cli
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Copy our custom wp-config.php over. This is arguably the most important
# part/trick, that makes WordPress container-friendly. Instead of hard-coding
# configuraion, we just loop through all environment variables and define
# them for use inside WordPress/PHP
COPY wp-config.php $WP_ROOT
RUN chown -R wordpress:www-data $WP_ROOT \
    && chmod 640 $WP_ROOT/wp-config.php

# Set proper ownership on Nginx's operational directories (for uploads)
RUN chown -R www-data:www-data /var/lib/nginx

# Copy all the configuration files into image root
COPY rootfs /

# Set the entrypoint which reads all the secret files to runtime ENV vars
ENTRYPOINT [ "docker-entrypoint.sh" ]

# We only expose port 80, but not 443. In a proper "containerized" manner
# HTTPS should be handled by a separate Nginx container/reverse proxy
EXPOSE 80

CMD [ "/usr/bin/supervisord", "-c", "/etc/supervisord.conf" ]
