# WordPress for Docker/Kubernetes

This is a 12-factor-ready WordPress image that is infinitely horizontally scaleable, meaning you can have as many servers (called _nodes_ in Kubernetes) with as many pods (containers) running.

### Getting started

#### With a fresh WordPress install

1. Download and extract WordPress into a project root directory
2. Delete everything _but_ `wp-content`
3. Copy both files from [examples](examples) to the project root directory
4. Modify `.env` and `docker-compose.yml` to fit your needs
5. Create a new directory, called `mysql` that you will mount into the container
6. Run `$ docker-compose up` and visit `http://localhost` (or any other hostname you are using for development, just make sure that `.env` has the correct values)

(Note that because we created a directory for MySQL the data will persist once we stop the containers with `CTRL + C`. If you use Git or any other VCS, you might want to add that directory to `.gitignore`)

### With an existing WordPress install

1. Open your project root directory
2. Delete everything _but_ `wp-content` (might want to do a backup first)
3. Copy both files from [examples](examples) to the project root directory
4. Modify `.env` and `docker-compose.yml` with your DB credentials
5. Create two new directories: `mysql` and `sql`.
6. Dump your development database into the `sql` directory.
7. Run `$ docker-compose up` and visit `http://localhost`
8. Delete the `sql` directory and remove the mount from `docker-compose.yml`

### About wp-content

In order to achieve scaleability, the image expects for `wp-content` directory to be mounted from an external source into `/var/www/wordpress/wp-content`.

By default it does come with it's own `wp-content`, but since docker images are immutable, you will loose all changes once the container is shut down.

### Environment variables and wp-config.php

The image comes with a modified `wp-config.php` that converts all environment variables into `define` calls you would normally do in there - this means there is no need to modify the file directly. In fact, for scalability, you are strongly advised not to. Instead, just pass all variables you need defined as an environment variables (with the exception of secrets, which are describe below).

The minimal set of environment variables you need to set for the image to run:
 - `DB_NAME`
 - `DB_USER`
 - `DB_HOST`
 - `DB_CHARSET`

### Handling secrets

Secrets are a special type of environment variables - ones that should not be stored in clear text, because they contain sensitive (or, you guessed it, _secret_) information.

Minimal set of secrets that WordPress uses out of the box are keys, salts and nonces (`AUTH_KEY`, `NONCE_KEY`, `NONCE_SALT`,..) you see in the default installation, plus `DB_PASSWORD`.

While it's perfectly fine to use the secrets as usual environment variables locally, they are huge security risk in production, especially since you'll be likely committing your code to a Git repository.

Kubernetes exposes secrets to containers with a special directory (which you define where it should be mounted) so that each secret becomes a file and the contents of that file is the actual secret. Example: if you set secrets to be mounted into `/var/secrets` then your `db-password` will be available inside `/var/secrets/db-password`.
That's why, this image comes with a startup script (inside `/usr/local/bin/docker-entrypoint.sh`) that loops through all the secrets files and exposes them as environment variables. For the script to work, you *must* set an environment variable `SECRETS_PATH` that points to the directory in which your secrets are mounted (see `examples/k8s/deployment.yml`).

General rule of thumb whether a configuration value should be a secret is that you wouldn't be comfortable committing it in a Git repository.

*Because secrets are passed into WordPress as environment variables, never ever print $_ENV on a production website as it will expose EVERYTHING to the outside world, which you probably don't want.*

### Sending emails

This image also comes with `postfix` installed, since the default WordPress install is capable of sending emails. While the default configuration might work on your local development machine, it will most likely fail in production - the reason being most of cloud providers block the default port (`25`) to fight spam.

That's why you're strongly encouraged to set the following environment variables:

- `SMTP_DOMAIN` - the domain you send emails from
- `SMTP_HOSTNAME` - server's hostname (can be the same as domain)
- `SMTP_SERVER` - email provider's server (Mandrill, Sendgrid, Mailgun, etc)
- `SMTP_USERNAME` - username/email for the email provider
- `SMTP_PASSWORD` - should be in _secrets_!
- `SMTP_PORT` - port for the email provider

You can find the last four values in your email provider's documentation.

### Your own Nginx virtual hosts

The default Nginx configuration will load all `*.conf` files inside `/var/www/wordpress/wp-content/nginx/`, which means you can provide your custom virtual hosts without the need to extend the image on your own. See [this example](examples/nginx.conf).

### FAQ
- What about container purity?
Many developers that use containers on a daily basis believe that each container should only have one process running, but that is a myth. Yes, we should strive for as few processes as possible, but having only one is in most cases impossible. Let's take Nginx for example; When it starts, the master process _will_ fork at least on worker, because master itself does not handle incoming requests. Same goes for PHP-FPM, postfix, syslog and many other open source projects. So then it comes down to someone else's code forking processes rather than your own.

### Caveats
- WordPress shouldn't be updated through `wp-admin` but rather a new version of this image should be deployed across all WordPress pods in the cluster.
- `wp-config.php` is locked and can't be modified. Some plugins want to `define` variables for their operation. In such cases, just set the environment variable yourself (see [deployment example](examples/k8s/deployment.yml`)).
- Some plugins (like WordFence) require files in WordPress root directory. Normally this is not a problem since those files can be safely moved into `wp-content` (which is shared among containers), just pay attention to file paths in those files.
- If you require additional/different php settings, feel free to pass those settings in Nginx config, like `fastcgi_param PHP_VALUE "auto_prepend_file=/var/www/wordpress/wp-content/wordfence-waf.php";` for example with WordFence.

---
This project, developed by [Codeable](https://codeable.io), is published under MIT License.
