<?php

$table_prefix = getenv('WP_TABLE_PREFIX') ?: 'wp_';

/*
 * This is where all the 12F magic happens. Instead of hard-coding
 * keys, passwords and settings, we provide those through environment
 * variables and expose them to PHP via `define`
 */
foreach ($_SERVER as $key => $value) {
  $capitalized = strtoupper($key);
  if (!defined($capitalized) && is_scalar($value)) {
    define($capitalized, $value);
  }
}

/**
 *  Prevent WordPress from auto-updating.
 *  This is important since we will most likely be running multiple
 *  separate instances that share only wp-content and we want to
 *  avoid any instance running different WP version than the rest.
 */
define('WP_AUTO_UPDATE_CORE', false);

/**
 * Since SSL termination is not this image's reponsibility, we need
 * to turn HTTPS setting on manually. SSL should be terminated on
 * the load balancer level
 */
if (strpos($_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false)
  $_SERVER['HTTPS']='on';


if (!defined('ABSPATH'))
    define('ABSPATH', dirname(__FILE__) . '/');

require_once(ABSPATH . 'wp-settings.php');
