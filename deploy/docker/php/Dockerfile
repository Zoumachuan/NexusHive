FROM php:8.1-fpm

# Install required packages and PHP extensions
RUN apt-get update && apt-get install -y \
    libzip-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    libicu-dev \
    git unzip curl && \
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j"$(nproc)" pdo_mysql mysqli gd mbstring bcmath zip intl && \
    pecl install redis && docker-php-ext-enable redis && \
    rm -rf /var/lib/apt/lists/*

# Recommended PHP settings for typical web apps
ENV PHP_MEMORY_LIMIT=512M \
    PHP_UPLOAD_MAX_FILESIZE=50M \
    PHP_POST_MAX_SIZE=50M \
    PHP_MAX_EXECUTION_TIME=300 \
    PHP_MAX_INPUT_VARS=2000

# Apply basic php.ini overrides
RUN { \
        echo "memory_limit=${PHP_MEMORY_LIMIT}"; \
        echo "upload_max_filesize=${PHP_UPLOAD_MAX_FILESIZE}"; \
        echo "post_max_size=${PHP_POST_MAX_SIZE}"; \
        echo "max_execution_time=${PHP_MAX_EXECUTION_TIME}"; \
        echo "max_input_vars=${PHP_MAX_INPUT_VARS}"; \
    } > /usr/local/etc/php/conf.d/docker-overrides.ini

WORKDIR /var/www/app
