# KubePress: WordPress image for Docker/Kubernetes

This is a 12-factor-ready WordPress image that is infinitely horizontally scaleable, meaning you can have as many servers (called _nodes_ in Kubernetes) with as many pods (containers) running. It comes with all WordPress dependencies installed (Nginx, PHP-FPM and postfix for sending emails)

## Getting started

#### With a fresh WordPress install

1. Download and extract WordPress into a project root directory
2. Delete everything _but_ `wp-content`
3. Copy both files from [examples](examples) to the project root directory
4. Modify `.env` and `docker-compose.yml` to fit your needs
5. Create a new directory, called `mysql` that you will mount into the container
6. Run `$ docker-compose up` and visit `http://localhost` (or any other hostname you are using for development, just make sure that `.env` has the correct values)

(Note that because we created a directory for MySQL the data will persist once we stop the containers with `CTRL + C`. If you use Git or any other VCS, you might want to add that directory to `.gitignore`)

#### With an existing WordPress install

1. Open your project root directory
2. Delete everything _but_ `wp-content` (might want to do a backup first)
3. Copy both files from [examples](examples) to the project root directory
4. Modify `.env` and `docker-compose.yml` with your DB credentials
5. Create two new directories: `mysql` and `sql`.
6. Dump your development database into the `sql` directory.
7. Run `$ docker-compose up` and visit `http://localhost`
8. Delete the `sql` directory and remove the mount from `docker-compose.yml`

## About wp-content

In order to achieve scaleability, the image expects for `wp-content` directory to be mounted from an external source into `/var/www/wordpress/wp-content`.

By default it does come with it's own `wp-content`, but since docker images are immutable, you will loose all changes once the container is shut down.

## Environment variables and wp-config.php

The image comes with a modified [`wp-config.php`](wp-config.php) that converts all environment variables into `define` calls you would normally do in there - this means there is no need to modify the file directly. In fact, for scalability, you are strongly advised not to. Instead, just pass all variables you need defined as an environment variables (with the exception of secrets, which are describe below).

The minimal set of environment variables you need to set for the image to run:
 - `DB_NAME`
 - `DB_USER`
 - `DB_HOST`
 - `DB_CHARSET`

## Handling secrets

Secrets are a special type of environment variables - ones that should not be stored in clear text, because they contain sensitive (or, you guessed it, _secret_) information.

Minimal set of secrets that WordPress uses out of the box are keys, salts and nonces (`AUTH_KEY`, `NONCE_KEY`, `NONCE_SALT`,..) you see in the default installation, plus `DB_PASSWORD`.

While it's perfectly fine to use the secrets as usual environment variables locally, they are huge security risk in production, especially since you'll be likely committing your code to a Git repository.

Kubernetes exposes secrets to containers with a special directory (which you define where it should be mounted) so that each secret becomes a file and the contents of that file is the actual secret. Example: if you set secrets to be mounted into `/var/secrets` then your `db-password` will be available inside `/var/secrets/db-password`.
That's why, this image comes with a startup script (inside [`usr/local/bin/docker-entrypoint.sh`](usr/local/bin/docker-entrypoint.sh#L10)) that loops through all the secrets files and exposes them as environment variables. For the script to work, you *must* set an environment variable `SECRETS_PATH` that points to the directory in which your secrets are mounted (see [`examples/k8s/deployment.yml`](examples/k8s/deployment.yml#L35)).

General rule of thumb whether a configuration value should be a secret is that you wouldn't be comfortable committing it in a Git repository.

**Because secrets are passed into WordPress as environment variables, never ever print $_ENV on a production website as it will expose EVERYTHING to the outside world, which you probably don't want.**

## Sending emails

Docker images are supposed to be as light-weight (and with limited responsibilities) as possible, which is why this image comes with a very basic `sendmail` installation, which will not work on it's own - you need to provide a mail relay to send emails, like Google's SMTP server. To get emails working, create a file `wp-content/mu-plugins/smtp-config.php` and put the following code in it:

```
<?php

defined( 'ABSPATH' ) or die( 'Please don\'t access this file directly.' );

/**
 * If the emails are still not sent properly, despite these settings
 * being set, visit https://myaccount.google.com/security and turn
 * on "Allow less secure apps". In any case, it's recommended to
 * create a separate email account for sending emails.
 *
 * You can either hard-code values in this file or provide them
 * via environment variables.
 */

add_action('phpmailer_init', 'smtp_config');

function smtp_config($phpmailer) {
  $phpmailer->isSMTP();
  $phpmailer->Host = 'smtp.gmail.com';
  $phpmailer->SMTPAutoTLS = true;
  $phpmailer->SMTPAuth = true;
  $phpmailer->Port = 587;
  $phpmailer->Username = $_ENV['SMTP_EMAIL'];
  $phpmailer->Password = $_ENV['SMTP_PASSWORD'];
}
```

## Your own Nginx virtual hosts

The default Nginx configuration will load all `*.conf` files inside `/var/www/wordpress/wp-content/nginx/`, which means you can provide your custom virtual hosts without the need to extend the image on your own. See [this example](examples/nginx.conf).

## FAQ
- **What about container purity?**
Many developers that use containers on a daily basis believe that each container should only have one process running, but that is a myth. Yes, we should strive for as few processes as possible, but having only one is in most cases impossible. Let's take Nginx for example; When it starts, the master process _will_ fork at least one worker, because master itself does not handle incoming requests. Same goes for PHP-FPM, postfix, syslog and many other open source projects. So then it comes down to someone else's code forking processes rather than your own.

## Caveats
- WordPress shouldn't be updated through `wp-admin` but rather a new version of this image should be deployed across all WordPress pods in the cluster.
- `wp-config.php` is locked and can't be modified. Some plugins want to `define` variables for their operation. In such cases, just set the environment variable yourself (see [deployment example](examples/k8s/deployment.yml`)).
- Some plugins (like WordFence) require files in WordPress root directory. Normally this is not a problem since those files can be safely moved into `wp-content` (which is shared among containers), just pay attention to file paths in those files.
- If you require additional/different php settings, feel free to pass those settings in Nginx config, like `fastcgi_param PHP_VALUE "auto_prepend_file=/var/www/wordpress/wp-content/wordfence-waf.php";` for example with WordFence.

## TODO:
- implement a proper init system ([s6](https://skarnet.org/software/s6/)/[runit](smarden.org/runit/))

---
This project, developed by [Codeable](https://codeable.io), is published under MIT License.
