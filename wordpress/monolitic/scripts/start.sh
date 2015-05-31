#!/bin/bash

# Configuration for wordpress
DB_HOST="localhost"
DB_USER="root"
DB_NAME_WORDPRESS="wp_testsite_local"
DB_USER_WORDPRESS="wp_testsite_local"
DB_HOST_WORDPRESS="localhost"
WP_FOLDER="/srv/www/vhost.testsite.local/www"
WP_URL="testsite.local"
WP_TITLE="testsite.local"
WP_ADMIN="admin"
WP_ADMIN_PASSWORD="admin"
WP_ADMIN_EMAIL="admin@testsite.local"

if [ ! -f $WP_FOLDER/wp-config.php ]; then
  # Generate passwords
  DB_PASSWORD=$(pwgen -cns 12 1)
  DB_PASSWORD_WORDPRESS=$(pwgen -cns 12 1)

  # database start & configure
  /usr/bin/mysqld_safe &
  while ! cat </dev/tcp/127.0.0.1/3306 2>&1 >/dev/null; do echo "Wait until mysql is up and running..."; sleep 5; done  # wait until mysqld_safe is up.
  mysqladmin password $DB_PASSWORD
  mysql -u$DB_USER -p$DB_PASSWORD -h$DB_HOST -e "
    GRANT ALL PRIVILEGES ON *.* TO '$DB_USER'@'$DB_HOST_WORDPRESS' IDENTIFIED BY '$DB_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;
    CREATE DATABASE IF NOT EXISTS $DB_NAME_WORDPRESS; 
    GRANT ALL PRIVILEGES ON $DB_NAME_WORDPRESS.* TO '$DB_USER_WORDPRESS'@'$DB_HOST_WORDPRESS' IDENTIFIED BY '$DB_PASSWORD_WORDPRESS'; 
    FLUSH PRIVILEGES;
  "

  # pre-install wordpress environment
  cd /srv/www/vhost.testsite.local/
  mkdir -p wordpress 
  ln -fs wordpress www
  cd wordpress

  # install wordpress
  wp --allow-root core download
  wp --allow-root core config --dbname=$DB_NAME_WORDPRESS --dbuser=$DB_USER_WORDPRESS --dbpass=$DB_PASSWORD_WORDPRESS
  wp --allow-root core install --url=$WP_URL --title=$WP_TITLE --admin_user=$WP_ADMIN --admin_password=$WP_ADMIN_PASSWORD --admin_email=$WP_ADMIN_EMAIL
  wp --allow-root plugin update --all
  wp --allow-root plugin install jetpack akismet wp-super-cache google-analytics-for-wordpress google-analytics-dashboard-for-wp 
  wp --allow-root plugin install wordpress-seo qtranslate-x wp-seo-qtranslate-x events-made-easy-qtranslate-x 
  wp --allow-root plugin install ewww-image-optimizer responsive-featured-image-widget broken-link-checker contact-form-7 buddypress
  wp --allow-root plugin install nginx-helper wp-smushit

  # post-install wordpress adjust permissions
  chown -R nginx:nginx /srv/www/vhost.testsite.local
  find /srv/www/vhost.testsite.local -type d -exec chmod 775 {} \;
  find /srv/www/vhost.testsite.local -type f -exec chmod 664 {} \;

  # Activate nginx plugin and set up pretty permalink structure once logged in

  # database stop 
  pkill mysqld

  # print and save configuration 
  echo "
     Initial configuration done 

     This is your configuration:
     * Environment variables
       DB_HOST=$DB_HOST \\
       DB_USER=$DB_USER \\
       DB_PASSWORD=$DB_PASSWORD \\
       DB_NAME_WORDPRESS=$DB_NAME_WORDPRESS \\
       DB_USER_WORDPRESS=$DB_USER_WORDPRESS \\
       DB_PASSWORD_WORDPRESS=$DB_PASSWORD_WORDPRESS \\
       DB_HOST_WORDPRESS=$DB_HOST_WORDPRESS \\
       WP_URL=$WP_URL \\
       WP_TITLE=$WP_TITLE \\
       WP_ADMIN=$WP_ADMIN \\
       WP_ADMIN_PASSWORD=$WP_ADMIN_PASSWORD \\
       WP_ADMIN_EMAIL=$WP_ADMIN_EMAIL \\
       WP_FOLDER=$WP_FOLDER

     * Mysql create statements
       GRANT ALL PRIVILEGES ON *.* TO '$DB_USER'@'$DB_HOST_WORDPRESS' IDENTIFIED BY '$DB_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;
       CREATE DATABASE IF NOT EXISTS $DB_NAME_WORDPRESS; 
       GRANT ALL PRIVILEGES ON $DB_NAME_WORDPRESS.* TO '$DB_USER_WORDPRESS'@'$DB_HOST_WORDPRESS' IDENTIFIED BY '$DB_PASSWORD_WORDPRESS'; 
       FLUSH PRIVILEGES;

     * Mysql cli
       mysql -p$DB_PASSWORD
       mysql -u$DB_USER_WORDPRESS -p$DB_PASSWORD_WORDPRESS $DB_NAME_WORDPRESS
    " | tee /start-config-wordpress.cfg
fi

# start services
/usr/bin/supervisord -n
