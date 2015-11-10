FROM ubuntu:14.04
MAINTAINER Sebastien LIU <sebastien.liu@publicisfrontfoot.com.au>

# Keep upstart from complaining
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -sf /bin/true /sbin/initctl

# Let the conatiner know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update
RUN apt-get -y upgrade

# Basic Requirements
RUN apt-get -y install \
  mysql-client \
  nginx \
  php5-fpm \
  php5-mysql \
  php-apc \
  python-setuptools \
  curl \
  git \
  unzip

# Wordpress Requirements
RUN apt-get -y install \
  php5-curl \
  php5-gd \
  php5-intl \
  php-pear \
  php5-imagick \
  php5-imap \
  php5-mcrypt \
  php5-memcache \
  php5-ming \
  php5-ps \
  php5-pspell \
  php5-recode \
  php5-sqlite \
  php5-tidy \
  php5-xmlrpc \
  php5-xsl

# nginx config
RUN sed -i -e"s/user\s*www-data/user www/" /etc/nginx/nginx.conf
RUN sed -i -e"s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf
RUN sed -i -e"s/keepalive_timeout\s*2/keepalive_timeout 2;\n\tclient_max_body_size 100m/" /etc/nginx/nginx.conf
RUN sed -i -e"s/#\s*gzip_vary\s*on/gzip_vary on/" /etc/nginx/nginx.conf
RUN sed -i -e"s/#\s*gzip_proxied\s*any/gzip_proxied any/" /etc/nginx/nginx.conf
RUN sed -i -e"s/#\s*gzip_comp_level\s*6/gzip_comp_level 6/" /etc/nginx/nginx.conf
RUN sed -i -e"s/#\s*gzip_buffers\s*16\s*8k/gzip_buffers 16 8k/" /etc/nginx/nginx.conf
RUN sed -i -e"s/#\s*gzip_http_version\s*1.1/gzip_http_version 1.1/" /etc/nginx/nginx.conf
RUN sed -i -e"s/#\s*gzip_types/gzip_types/" /etc/nginx/nginx.conf
RUN echo "daemon off;" >> /etc/nginx/nginx.conf

# php-fpm config
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php5/fpm/php.ini
RUN sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php5/fpm/php.ini
RUN sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php5/fpm/php.ini
RUN sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php5/fpm/php-fpm.conf
RUN sed -i -e "s/;log_level\s*=\s*notice/log_level = debug/g" /etc/php5/fpm/php-fpm.conf
RUN sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php5/fpm/pool.d/www.conf
RUN find /etc/php5/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;

# nginx site conf
ADD ./nginx-site.conf /etc/nginx/sites-available/default

# Supervisor Config
RUN /usr/bin/easy_install supervisor
RUN /usr/bin/easy_install supervisor-stdout
ADD ./supervisord.conf /etc/supervisord.conf

# Install Wordpress
ADD https://wordpress.org/latest.tar.gz /usr/share/nginx/latest.tar.gz
RUN cd /usr/share/nginx/ && tar xvf latest.tar.gz && rm latest.tar.gz
RUN mv /usr/share/nginx/html/5* /usr/share/nginx/wordpress
RUN rm -rf /usr/share/nginx/www
RUN mv /usr/share/nginx/wordpress /usr/share/nginx/www
RUN rm -rf /usr/share/nginx/www/wp-content/themes/twentyfourteen
RUN rm -rf /usr/share/nginx/www/wp-content/themes/twentythirteen

# Copy wp-config file and wp-content
COPY ./wp-config.php /usr/share/nginx/www/

# Wordpress Initialization and Startup Script
ADD ./start.sh /start.sh
RUN chmod 755 /start.sh

# private expose
EXPOSE 80

# volume for wordpress install
VOLUME ["/usr/share/nginx/www"]

CMD ["/bin/bash", "/start.sh"]
