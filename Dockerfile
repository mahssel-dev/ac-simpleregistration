FROM php:8.2-apache

FROM php:8.2-apache

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      git unzip \
      pkg-config \
      libzip-dev \
      libxml2-dev \
      libonig-dev \
      libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
      libgmp-dev \
    ; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install -j"$(nproc)" \
      gd gmp zip soap mbstring pdo pdo_mysql

‚RUN { \
  echo "log_errors=On"; \
  echo "error_reporting=E_ALL"; \
  echo "display_errors=On"; \
  echo "error_log=/proc/self/fd/2"; \
} > /usr/local/etc/php/conf.d/99-docker-logging.ini

RUN a2enmod rewrite

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html
COPY . /var/www/html

RUN cd /var/www/html/application && composer install --no-dev --prefer-dist --no-interaction

RUN chown -R www-data:www-data /var/www/html

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]
