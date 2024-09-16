# Install system dependencies required both at runtime and build time
FROM ruby:3.3.5-alpine AS base
RUN apk update
RUN apk add gcc sqlite sqlite-dev mariadb-dev mariadb-server-utils redis memcached
RUN apk add git bash build-base

# This stage will be responsible for installing gems and npm packages
FROM base AS dependencies
WORKDIR /app
USER root
COPY Gemfile Gemfile.lock ./
ENV WITHOUT_GEMS="development test"
RUN bundle config set --without "${WITHOUT_GEMS}"
RUN bundle install --jobs $(nproc)

FROM base AS production
WORKDIR /app
ENV USER=app
ARG UID=1000
# RUN id -u "$USER" &>/dev/null || useradd --uid "${UID}" "${USER}" # debian based
RUN id -u "$USER" &>/dev/null || adduser --disabled-password --uid "${UID}" "${USER}"

USER root
COPY --from=dependencies --chown=${USER} /usr/local/bundle/ /usr/local/bundle/
COPY --chown=${USER} . ./
USER ${USER}
RUN chmod +x entrypoint.sh
ENTRYPOINT ["./entrypoint.sh"]
CMD ["bundle","exec","puma"]

FROM production AS development
ENV USER=app
USER ${USER}
# USER root
ENV WITH_GEMS="development test"
RUN bundle config set --with "${WITH_GEMS}"
RUN bundle install --jobs $(nproc)
