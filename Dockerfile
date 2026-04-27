FROM wordpress:6.5-php8.2-apache
ARG CACHEBUST=1

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates default-mysql-client && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/log/apache2

# Ensure only prefork MPM is enabled (mod_php requires this).
RUN rm -f /etc/apache2/mods-enabled/mpm_event.load /etc/apache2/mods-enabled/mpm_event.conf /etc/apache2/mods-enabled/mpm_worker.load /etc/apache2/mods-enabled/mpm_worker.conf && \
    a2enmod mpm_prefork

# Listen on both 80 and 8080 to avoid platform port-mapping mismatches.
RUN grep -q '^Listen 8080$' /etc/apache2/ports.conf || echo 'Listen 8080' >> /etc/apache2/ports.conf && \
    cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default-8080.conf && \
    sed -i 's/<VirtualHost \\*:80>/<VirtualHost *:8080>/' /etc/apache2/sites-available/000-default-8080.conf && \
    a2ensite 000-default-8080 >/dev/null && \
    sed -i '1i ServerName localhost' /etc/apache2/apache2.conf && \
    sed -i '/<VirtualHost \\*:80>/a\\    php_admin_value auto_prepend_file none' /etc/apache2/sites-available/000-default.conf && \
    sed -i '/<VirtualHost \\*:8080>/a\\    php_admin_value auto_prepend_file none' /etc/apache2/sites-available/000-default-8080.conf && \
    sed -i 's|ErrorLog \\${APACHE_LOG_DIR}/error.log|ErrorLog /proc/self/fd/2|' /etc/apache2/sites-available/000-default.conf && \
    sed -i 's|CustomLog \\${APACHE_LOG_DIR}/access.log combined|CustomLog /proc/self/fd/1 combined|' /etc/apache2/sites-available/000-default.conf && \
    sed -i 's|ErrorLog \\${APACHE_LOG_DIR}/error.log|ErrorLog /proc/self/fd/2|' /etc/apache2/sites-available/000-default-8080.conf && \
    sed -i 's|CustomLog \\${APACHE_LOG_DIR}/access.log combined|CustomLog /proc/self/fd/1 combined|' /etc/apache2/sites-available/000-default-8080.conf

# Install WP-CLI for safe serialized search-replace after SQL import.
RUN curl -fsSL -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x /usr/local/bin/wp

RUN echo "cachebust=${CACHEBUST}"

# The image keeps WordPress source under /usr/src/wordpress.
# Copy it into the web root so index.php and core files always exist.
RUN cp -a /usr/src/wordpress/. /var/www/html/

# Keep a clean core snapshot used by entrypoint for restoring vendor polyfills if missing.
RUN mkdir -p /opt/base-core/wp-includes && cp -a /var/www/html/wp-includes/. /opt/base-core/wp-includes/

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

EXPOSE 80
EXPOSE 8080

# Start Apache directly (disable custom bootstrap logic).
CMD ["apache2-foreground"]

