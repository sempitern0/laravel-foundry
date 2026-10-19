FROM php:8.4-fpm-bookworm AS base
RUN apt-get update && apt-get install -y --no-install-recommends git unzip libpq-dev libicu-dev libzip-dev libonig-dev libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" pdo_pgsql intl zip mbstring bcmath pcntl gd opcache \
 && rm -rf /var/lib/apt/lists/*
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /var/www/html
# Composer hooks of the official Laravel starter kits can invoke npm
# (e.g. Laravel Chisel's artisan install:features). Node must therefore be
# available INSIDE the development PHP container, not only in Vite's service.
FROM node:22-bookworm-slim AS node-toolchain
FROM base AS development
COPY --from=node-toolchain /usr/local/bin/node /usr/local/bin/node
COPY --from=node-toolchain /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
 && node --version && npm --version \
 && cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
FROM base AS production
RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY app/composer.json app/composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist --no-progress --no-scripts --optimize-autoloader
COPY app/ ./
RUN composer dump-autoload --no-dev --optimize --no-interaction \
 && mkdir -p storage/framework/cache storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
 && chown -R www-data:www-data storage bootstrap/cache
USER www-data
CMD ["php-fpm"]
