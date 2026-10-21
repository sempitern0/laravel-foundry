FROM php:8.4-fpm-bookworm AS base
RUN apt-get update && apt-get install -y --no-install-recommends git unzip libpq-dev libicu-dev libzip-dev libonig-dev libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" pdo_pgsql pdo_mysql intl zip mbstring bcmath pcntl gd opcache \
 && rm -rf /var/lib/apt/lists/*
# phpRedis is required when QUEUE_CONNECTION=redis; use the same extension in
# PHP-FPM, worker and tooling images instead of relying on an optional image.
RUN pecl install redis-6.3.0 && docker-php-ext-enable redis && php --ri redis >/dev/null
WORKDIR /var/www/html
FROM base AS development
RUN cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
# Laravel starter Composer hooks can run npm (e.g. install:features).
# Both belong to the disposable toolbox, not the long-running PHP runtime.
FROM node:22-bookworm-slim AS node-toolchain
# Wayfinder runs PHP Artisan from Vite during both dev and build.
# Frontend CLI must have PHP/extensions, but should not need Composer.
FROM development AS frontend
COPY --from=node-toolchain /usr/local/bin/node /usr/local/bin/node
COPY --from=node-toolchain /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
 && node --version && npm --version && php --version
FROM frontend AS tooling
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
RUN composer --version
FROM base AS production
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY app/composer.json app/composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist --no-progress --no-scripts --optimize-autoloader
COPY app/ ./
RUN composer dump-autoload --no-dev --optimize --no-interaction \
 && mkdir -p storage/framework/cache storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
 && chown -R www-data:www-data storage bootstrap/cache
USER www-data
CMD ["php-fpm"]
