FROM php:8.2-apache

RUN apt-get update && apt-get install -y \
    git unzip libzip-dev \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libgmp-dev \
 && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" \
    gd gmp zip soap mbstring pdo pdo_mysql

RUN a2enmod rewrite

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html
COPY . /var/www/html

RUN cd /var/www/html/application && composer install --no-dev --prefer-dist --no-interaction

RUN chown -R www-data:www-data /var/www/html
