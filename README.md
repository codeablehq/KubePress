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

Minimal set of secrets that WordPress uses out of the box are keys, salts and nonces (`AUTH_KEY`, `NONCE_KEY`, `NONCE_SALT`,..) you see in the default installation, plus `DB_PASSWORD` and `SMTP_PASSWORD`.

While it's perfectly fine to use the secrets as usual environment variables locally, they are huge security risk in production, especially since you'll be likely committing your code to a Git repository.

Kubernetes exposes secrets to containers with a special directory so that each secret becomes a file and the contents of that file is the actual secret. Example: Set secrets to be mounted into `/etc/environment` then your `DB_PASSWORD` will be available inside `/etc/environment/DB_PASSWORD`. See [`examples/k8s/deployment.yml`](examples/k8s/deployment.yml#L35).

General rule of thumb whether a configuration value should be a secret is that you wouldn't be comfortable committing it in a Git repository.

**Because secrets are passed into WordPress as environment variables, never ever print $_ENV on a production website as it will expose EVERYTHING to the outside world, which you probably don't want.**

## Sending emails

This image comes with an [Exim4](http://www.exim.org/) installation, which will work on it's own, but you will most likely have difficulties receiving this email because Exim's default port is `25` - one that most cloud providers block for spamming reasons. That's why you can provide the necessary information through environment variables that will reconfigure Exim to behave as a _smarthost_, one that connects to a proper email sending provider of your choice (such as SendGrid or Mandrill).

The variables you can define are:
- `SMTP_POSTMASTER` is the default _from_ address, highly recommended you set this one regardless if you use an external provider or not
- `SMTP_DOMAN` is the main domain your WordPress runs on
- `SMTP_HOST` is the email provider's server (such as `smtp.mandrillapp.com`)
- `SMTP_PORT` is the email provider's server port (often `587`)
- `SMTP_USERNAME` and `SMTP_PASSWORD` are the email provider's credentials


Alternatively, you can also bypass Exim4 completely and configure WordPress to connect to an external provider directly, with a _must use plugin_. To get that up and running, create a file `wp-content/mu-plugins/smtp-config.php` and put the following code in it:

```
<?php
/**
 * Plugin Name: SMTP Config
 * Description: Uses an external provider to send emails from WordPress
 * Author:      Tomaz Zaman
 * Author URI:  https://codeable.io
 * Version:     1.0
 * Licence:     MIT
 */

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
  $phpmailer->Username = $_ENV['SMTP_USERNAME'];
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

---
This project, developed by [Codeable](https://codeable.io), is published under MIT License.
