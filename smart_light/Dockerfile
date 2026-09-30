FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
ARG API_BASE_URL=https://smart-light.tech
RUN flutter build web --release --base-href=/app/ --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:alpine
ARG NGINX_CONFIG=deploy/nginx.conf
COPY ${NGINX_CONFIG} /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html/app
COPY web/about.html /usr/share/nginx/html/about.html
COPY web/about-assets /usr/share/nginx/html/about-assets
EXPOSE 80
