FROM php:7.0-apache

MAINTAINER Raphael Bicker

ENV MYSQL_ICINGAWEB_DB icingaweb2
ENV MYSQL_ICINGAWEB_USER icingaweb2
ENV MYSQL_ICINGAWEB_PASSWORD icingaweb2

ENV MYSQL_DIRECTOR_DB director
ENV MYSQL_DIRECTOR_USER director
ENV MYSQL_DIRECTOR_PASSWORD director

ENV ADMIN_USER admin
ENV ADMIN_PASSWORD admin

ENV DEBIAN_FRONTEND noninteractive     

RUN apt-get -q update \
  && apt-get -qqy upgrade \
  && apt-get install -y git mysql-client \
    zlib1g-dev libicu-dev g++ libpng12-dev libjpeg62-turbo-dev  libfreetype6-dev libldap2-dev libcurl4-openssl-dev

RUN docker-php-ext-configure intl \
  && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
  && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu \
  && docker-php-ext-install -j$(nproc) intl gd ldap gettext curl pdo pdo_mysql mysqli

RUN a2enmod rewrite

RUN addgroup --system icingaweb2 \
  && usermod -a -G icingaweb2 www-data  

RUN git clone http://git.icinga.org/icingaweb2.git /usr/share/icingaweb2 \
  && git clone http://github.com/Icinga/icingaweb2-module-director.git /usr/share/icingaweb2/modules/director
  
RUN /usr/share/icingaweb2/bin/icingacli setup config directory \
  && mkdir -p /etc/icingaweb2/modules/monitoring \
  && mkdir -p /etc/icingaweb2/modules/director

RUN /usr/share/icingaweb2/bin/icingacli setup config webserver apache --document-root /usr/share/icingaweb2/public > /etc/apache2/conf-available/icingaweb2.conf \
  && a2enconf icingaweb2 \
  && echo "RedirectMatch ^/$ /icingaweb2/" >> /etc/apache2/apache2.conf
  
ADD content/ /

VOLUME ["/etc/icingaweb2"]

EXPOSE 80 443

RUN chmod +x /run.sh

CMD ["/run.sh"]