<?php

$table_prefix = getenv('WP_TABLE_PREFIX') ?: 'wp_';

/*
 * This is where all the 12F magic happens. Instead of hard-coding
 * keys, passwords and settings, we provide those through environment
 * variables and expose them to PHP via `define`
 */
foreach ($_ENV as $key => $value) {
  $capitalized = strtoupper($key);
  if (!defined($capitalized)) {
    define($capitalized, $value);
  }
}

if (strpos($_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false)
    $_SERVER['HTTPS']='on';

if (!defined('ABSPATH'))
    define('ABSPATH', dirname(__FILE__) . '/');

require_once(ABSPATH . 'wp-settings.php');
