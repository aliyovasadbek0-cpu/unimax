FROM wordpress:6.5-php8.2-fpm
ARG CACHEBUST=1

RUN apt-get update && \
    apt-get install -y --no-install-recommends nginx supervisor ca-certificates default-mysql-client && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /run/php /var/log/supervisor

RUN curl -fsSL -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x /usr/local/bin/wp

RUN echo "cachebust=${CACHEBUST}"

RUN cp -a /usr/src/wordpress/. /var/www/html/

RUN mkdir -p /opt/base-core/wp-includes && cp -a /var/www/html/wp-includes/. /opt/base-core/wp-includes/

RUN if [ -f /usr/local/etc/php-fpm.d/www.conf ]; then \
      sed -i 's|^listen = .*|listen = 127.0.0.1:9000|' /usr/local/etc/php-fpm.d/www.conf; \
    fi

COPY wp-content /var/www/html/wp-content
COPY wp-config.php /var/www/html/wp-config.php
COPY unimaxtecdbs.sql /var/www/html/unimaxtecdbs.sql
COPY health /var/www/html/health

RUN mkdir -p /opt/www-seed && cp -a /var/www/html/wp-content/. /opt/www-seed/wp-content/

RUN chown -R www-data:www-data /var/www/html

COPY docker/nginx.conf.template /etc/nginx/nginx.conf.template
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY docker/entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

ENV PORT=8080
EXPOSE 80
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
