FROM wordpress:6.5-php8.2-apache
ARG CACHEBUST=1

RUN apt-get update && \
    apt-get install -y --no-install-recommends default-mysql-client && \
    rm -rf /var/lib/apt/lists/*

# Railway forwards HTTP to $PORT (often 8080). Do not touch Apache MPM — stock image is stable.
ENV PORT=8080

RUN curl -fsSL -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x /usr/local/bin/wp

RUN echo "cachebust=${CACHEBUST}"

RUN cp -a /usr/src/wordpress/. /var/www/html/

RUN mkdir -p /opt/base-core/wp-includes && cp -a /var/www/html/wp-includes/. /opt/base-core/wp-includes/

COPY wp-content /var/www/html/wp-content
COPY wp-config.php /var/www/html/wp-config.php
COPY unimaxtecdbs.sql /var/www/html/unimaxtecdbs.sql
COPY health /var/www/html/health

RUN mkdir -p /opt/www-seed && cp -a /var/www/html/wp-content/. /opt/www-seed/wp-content/

RUN chown -R www-data:www-data /var/www/html

COPY docker/entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
CMD ["apache2-foreground"]
