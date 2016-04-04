<?php

define('DB_NAME',     '{{VAGRANT_MYSQL_DB}}');
define('DB_USER',     '{{VAGRANT_MYSQL_USER}}');
define('DB_PASSWORD', '{{VAGRANT_MYSQL_PASSWORD}}');
define('DB_HOST',     'localhost');
define('DB_CHARSET',  'utf8');


$table_prefix = 'wp_';

{{KEYS}}

define('WP_DEBUG', true);
define('WP_HOME', 'http://{{VAGRANT_IP}}');
define('WP_SITEURL', 'http://{{VAGRANT_IP}}');

if (!defined('ABSPATH'))
	define('ABSPATH', dirname(__FILE__) . '/');

require_once(ABSPATH . 'wp-settings.php');
