FROM ubuntu:14.04
MAINTAINER Sebastien LIU <sebastien.liu@publicisfrontfoot.com.au>

# Version
ENV NGINX_VERSION 1.8.0
ENV NPS_VERSION 1.9.32.6
ENV OPENSSL_VERSION 1.0.1p

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

# Install Build Tools
RUN apt-get build-dep nginx-full -y &&\
  apt-get install -y build-essential zlib1g-dev libpcre3 libpcre3-dev &&\
  apt-get install wget -y &&\
  apt-get clean &&\
  rm -rf /var/lib/apt/lists/*

# ===================================
# Build Nginx with PageSpeed enabled
# ===================================

# Setting Up ENV
ENV MODULE_DIR /usr/src/nginx-modules

# Create Module Directory
RUN mkdir ${MODULE_DIR}

# Download Source
RUN cd /usr/src && \
    wget -q http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar xzf nginx-${NGINX_VERSION}.tar.gz && \
    rm -rf nginx-${NGINX_VERSION}.tar.gz && \

    cd /usr/src && \
    wget -q http://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz && \
    tar xzf openssl-${OPENSSL_VERSION}.tar.gz && \
    rm -rf openssl-${OPENSSL_VERSION}.tar.gz && \

    # Install Addational Module
    cd ${MODULE_DIR} && \
    wget -q --no-check-certificate https://github.com/pagespeed/ngx_pagespeed/archive/release-${NPS_VERSION}-beta.tar.gz && \
    tar zxf release-${NPS_VERSION}-beta.tar.gz && \
    rm -rf release-${NPS_VERSION}-beta.tar.gz && \
    cd ngx_pagespeed-release-${NPS_VERSION}-beta/ && \
    wget -q --no-check-certificate https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz && \
    tar zxf ${NPS_VERSION}.tar.gz && \
    rm -rf ${NPS_VERSION}.tar.gz && \

    # Compile Nginx
    cd /usr/src/nginx-${NGINX_VERSION} && \
    ./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_random_index_module \
    --with-http_stub_status_module \
    --with-http_auth_request_module \
    --with-http_ssl_module \
    --with-http_realip_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_secure_link_module \
    --with-http_spdy_module \
    --with-file-aio \
    --with-ipv6 \
    --with-sha1=/usr/include/openssl \
    --with-md5=/usr/include/openssl \
    --with-openssl="../openssl-${OPENSSL_VERSION}" \
    --add-module=${MODULE_DIR}/ngx_pagespeed-release-${NPS_VERSION}-beta && \

    # Install Nginx
    cd /usr/src/nginx-${NGINX_VERSION} && \
    make && make install && \

    # Clear source code to reduce container size
    rm -rf /usr/src/*

# ===================
# End Building Nginx
# ===================

# nginx config
COPY ./nginx.conf.default /etc/nginx/nginx.conf
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
#RUN mv /usr/share/nginx/html/5* /usr/share/nginx/wordpress
COPY ./html/50x.html /usr/share/nginx/wordpress/
RUN rm -rf /usr/share/nginx/www
RUN mv /usr/share/nginx/wordpress /usr/share/nginx/www
RUN rm -rf /usr/share/nginx/www/wp-content/themes/twentyfourteen
RUN rm -rf /usr/share/nginx/www/wp-content/themes/twentythirteen

# Copy wp-config file and wp-content
COPY ./wp-config.php /usr/share/nginx/www/
COPY ./wp-content /usr/share/nginx/www/wp-content/
RUN chown -R www-data:www-data /usr/share/nginx/www

# Wordpress Initialization and Startup Script
ADD ./start.sh /start.sh
RUN chmod 755 /start.sh

# Forward requests and errors to docker logs
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

# private expose
EXPOSE 80

# volume for wordpress install
VOLUME ["/usr/share/nginx/www", "/var/cache/nginx", "/var/cache/ngx_pagespeed"]

CMD ["/bin/bash", "/start.sh"]
