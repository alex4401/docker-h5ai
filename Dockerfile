FROM alpine AS builder

# Download QEMU, see https://github.com/docker/hub-feedback/issues/1261
ENV QEMU_URL https://github.com/balena-io/qemu/releases/download/v3.0.0%2Bresin/qemu-3.0.0+resin-arm.tar.gz
RUN apk add curl && curl -L ${QEMU_URL} | tar zxvf - -C . --strip-components 1


FROM arm32v7/alpine:3.12.1
MAINTAINER alex4401 <rylatgl@gmail.com>

# Add QEMU
COPY --from=builder qemu-arm-static /usr/bin

ENV H5AI_VERSION=0.29.2
ENV TS=Europe/Warsaw

RUN apk --update --no-cache add \
    wget supervisor unzip patch nginx \
    php7 php7-fpm php7-opcache php7-gd && \
    rm /etc/nginx/conf.d/default.conf

# install h5ai and patch configuration
RUN apk --update --no-cache add ca-certificates && \
    wget https://release.larsjung.de/h5ai/h5ai-$H5AI_VERSION.zip && \
    unzip h5ai-$H5AI_VERSION.zip -d /usr/share/h5ai && \
    rm h5ai-$H5AI_VERSION.zip

# patch h5ai
ADD class-setup.php.patch class-setup.php.patch
RUN patch -p1 -u -d /usr/share/h5ai/_h5ai/private/php/core -i /class-setup.php.patch && rm class-setup.php.patch
ADD options.json.patch options.json.patch
RUN patch -p1 -u -d /usr/share/h5ai/_h5ai/private/conf/ -i /options.json.patch && rm options.json.patch

# add h5ai as the only nginx site
ADD nginx.conf /etc/nginx/nginx.conf
ADD fpm-pool.conf /etc/php7/php-fpm.d/www.conf
ADD php.ini /etc/php7/conf.d/custom.ini

RUN mkdir /run/php && \
    chown -R nobody:nobody /usr/share/h5ai && \
    chown -R nobody:nobody /run/php && \
    chown -R nobody:nobody /var/lib/nginx && \
    chown -R nobody:nobody /var/log/nginx
USER nobody
WORKDIR /var/www

# use supervisor to monitor all services
ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD supervisord -c /etc/supervisor/conf.d/supervisord.conf

# expose only nginx HTTP port
EXPOSE 80

# expose path
VOLUME /var/www

