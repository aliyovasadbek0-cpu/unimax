FROM wordpress:6.5-php8.2-fpm
ARG CACHEBUST=1

RUN apt-get update && \
    apt-get install -y --no-install-recommends nginx supervisor gettext-base ca-certificates default-mysql-client && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /run/php /var/log/supervisor

# Install WP-CLI for safe serialized search-replace after SQL import.
RUN curl -fsSL -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x /usr/local/bin/wp

RUN echo "cachebust=${CACHEBUST}"

# The image keeps WordPress source under /usr/src/wordpress.
# Copy it into the web root so index.php and core files always exist.
RUN cp -a /usr/src/wordpress/. /var/www/html/

# Keep a clean core snapshot used by entrypoint for restoring vendor polyfills if missing.
RUN mkdir -p /opt/base-core/wp-includes && cp -a /var/www/html/wp-includes/. /opt/base-core/wp-includes/

# Ensure php-fpm listens on TCP 9000 (for nginx upstream).
RUN if [ -f /usr/local/etc/php-fpm.d/www.conf ]; then \
      sed -i 's|^listen = .*|listen = 0.0.0.0:9000|' /usr/local/etc/php-fpm.d/www.conf; \
    fi

# Copy only the parts we actually want to override:
# - wp-content (plugins/themes/uploads)
# - wp-config.php (DB config)
# - DB dump for first-run import
COPY wp-content /var/www/html/wp-content
COPY wp-config.php /var/www/html/wp-config.php
COPY unimaxtecdbs.sql /var/www/html/unimaxtecdbs.sql

# Seed snapshot for cases where Railway mounts an empty disk over wp-content.
RUN mkdir -p /opt/www-seed && cp -a /var/www/html/wp-content/. /opt/www-seed/wp-content/

# Ensure correct ownership for WordPress to write to wp-content
RUN chown -R www-data:www-data /var/www/html

# Nginx template (PORT substituted at container start — must match Railway $PORT).
COPY docker/nginx.conf.template /etc/nginx/nginx.conf.template
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Restore startup script for DB import and runtime normalization.
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENV PORT=8080
EXPOSE 8080

# Run startup bootstrap, then start php-fpm + nginx.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

