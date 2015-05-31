FROM centos:7

# pre-install permissions adjustment adding local UIDs for volume friendly permissions between host and container
ADD ./configs/passwd ./configs/group /tmp/

RUN cd /tmp \
   && cat passwd | join -t: -j 1 -v 2 --nocheck-order /etc/passwd - | join -t: -j 3 -v 2 -o 2.1,2.2,2.3,2.4,2.5,2.6 --nocheck-order /etc/passwd - >> /etc/passwd \
   && cat group | join -t: -j 1 -v 2 --nocheck-order /etc/group - | join -t: -j 3 -v 2 -o 2.1,2.2,2.3,2.4 --nocheck-order /etc/group - >> /etc/group \
   && rm passwd group \
   && pwck -s /etc/passwd \
   && grpck -s /etc/group 

# Add repositories for centos: nginx.repo, mariadb.repo
ADD ./configs/*.repo /etc/yum.repos.d/

RUN rpm --import http://rpms.famillecollet.com/RPM-GPG-KEY-remi \
   && rpm -i http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm \
   && rpm -i http://rpms.famillecollet.com/enterprise/remi-release-7.rpm \
   && sed -i '/\[remi\]/,+5 s/enabled=0/enabled=1/' /etc/yum.repos.d/remi.repo \
   && sed -i '/\[remi-php56\]/,+5 s/enabled=0/enabled=1/' /etc/yum.repos.d/remi.repo \
# Add base packages \
   && yum -y update \
   && yum -y install hostname curl git tar unzip pwgen nc socat lsof python-setuptools python-pip \
# Add friendly commandline environment \
   && yum -y install bash-completion vim-enhanced \
   && echo "set background=dark" >> /etc/bashrc \
   && sed -i "/#.*aliases/a alias vi='vim'" /root/.bashrc \
   && yum -y clean all

# Add webserver nginx
RUN yum -y install nginx \
   && mkdir -p /srv/www/vhost.testsite.local/www/ /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/global \
   && chown nginx:nginx /srv/www/* \
   && sed -i "\%include /etc/nginx/conf.d/\*.conf;% a include /etc/nginx/sites-enabled/\*;" /etc/nginx/nginx.conf \
   && sed -i "s/keepalive_timeout *65/keepalive_timeout 2/" /etc/nginx/nginx.conf \
   && sed -i "/keepalive_timeout 2/a client_max_body_size 100m;" /etc/nginx/nginx.conf \
   && yum -y clean all

# Add webserver nginx configuration files
ADD ./configs/nginx/global/ /etc/nginx/global/
ADD ./configs/nginx/conf.d/php-backend.conf /etc/nginx/conf.d/php-backend.conf
ADD ./configs/nginx/sites-available/nginx-testsite.local /etc/nginx/sites-available/testsite.local
RUN ln -s /etc/nginx/sites-available/testsite.local /etc/nginx/sites-enabled/testsite.local 

# Add database mariaDB
RUN yum -y install MariaDB-server MariaDB-client \
   && mkdir -p /var/run/mysqld/ \
   && chown root:mysql /var/run/mysqld/ \
   && chmod 775 /var/run/mysqld/ \
   && yum -y clean all

# Add backend PHP
RUN yum -y install php php-fpm php-common \
   && sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php.ini \
   && sed -i "s/upload_max_filesize *= *2M/upload_max_filesize = 100M/g" /etc/php.ini \
   && sed -i "s/post_max_size *= *8M/post_max_size = 100M/g" /etc/php.ini \
   && sed -i "/;catch_workers_output *= *yes/ s/^;//" /etc/php-fpm.d/www.conf \
   && sed -i "s/user *= *apache/user = nginx/g" /etc/php-fpm.d/www.conf \
   && sed -i "s/group *= *apache/group = nginx/g" /etc/php-fpm.d/www.conf \
   && sed -i "s/;listen.group *= *nobody/listen.group = nginx/g" /etc/php-fpm.d/www.conf \
   && sed -i "s%listen *= *127.0.0.1:9000%listen = /var/run/php5-fpm.sock%g" /etc/php-fpm.d/www.conf \
   && sed -i "/php_value\[soap.wsdl_cache_dir\]/ s/^/;/" /etc/php-fpm.d/www.conf \
   && chown root:nginx /var/lib/php/session /var/lib/php/wsdlcache \
   && yum -y clean all

# Add backend PHP cache layer and optional components
RUN yum -y install php-opcache php-pecl-apcu php-cli php-pear php-pecl-memcache php-pecl-memcached \ 
                   php-gd php-mbstring php-mcrypt php-xml php-pdo php-mysqlnd php-pgsql php-pecl-mongo php-pecl-sqlite \
   && sed -i "s/;opcache.revalidate_freq=2/opcache.revalidate_freq=60/g" /etc/php.d/*opcache.ini \
   # Add some configuration for moodle \
   && sed -i "/;opcache.use_cwd *= *1/ s/^;//" /etc/php.d/*opcache.ini \
   && sed -i "/;opcache.validate_timestamps *= *1/ s/^;//" /etc/php.d/*opcache.ini \
   && sed -i "/;opcache.save_comments *= *1/ s/^;//" /etc/php.d/*opcache.ini \
   && sed -i "/;opcache.enable_file_override *= *0/ s/^;//" /etc/php.d/*opcache.ini

# Install application wordpress
ADD http://wordpress.org/latest.tar.gz /srv/www/vhost.testsite.local/wordpress-latest.tar.gz
RUN cd /srv/www/vhost.testsite.local/ \
   && mkdir -p wordpress \
   && tar xvf wordpress-latest.tar.gz \ 
   && rm -f wordpress-latest.tar.gz \
   && rm -rf /srv/www/vhost.testsite.local/www \
   && ln -s /srv/www/vhost.testsite.local/wordpress /srv/www/vhost.testsite.local/www

# post-install permissions adjustment to get friendly mapping with host and container
RUN useradd -r nginx -s /sbin/nologin || true \
   && groupadd -f www-data \
   && usermod -aG www-data nginx \
   && chown -R nginx:www-data /srv/www/vhost.testsite.local \
   && find /srv/www/vhost.testsite.local -type d -exec chmod 775 {} \; \
   && find /srv/www/vhost.testsite.local -type f -exec chmod 664 {} \; 

# Prepare running state through supervisord
RUN easy_install supervisor supervisor-stdout syslog-stdout \
   && sed -i "1 i daemon off; #supervisord will keep control" /etc/nginx/nginx.conf \
   && sed -i "s/daemonize *= *yes/daemonize = no ;supervisord will keep control/g" /etc/php-fpm.conf

ADD ./configs/supervisord.conf /etc/supervisord.conf
ADD ./scripts/start.sh /start.sh
RUN chmod 755 /start.sh

# Expose volumes
VOLUME /srv/www/vhost.testsite.local/wordpress

# Expose ports
EXPOSE 3306
EXPOSE 80

# Crank it up
CMD ["/bin/bash", "/start.sh"]
