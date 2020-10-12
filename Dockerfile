FROM bitwalker/alpine-elixir-phoenix:1.7.1 as releaser

ENV \
  LANGUAGE='en_US:en' \
  LANG='en_US.UTF-8' \
  LC_CTYPE='en_IN.UTF-8'\
  LC_ALL='en_US.UTF-8' \
  PATH="/app:${PATH}" \
  FWUP_VERSION=1.8.1 \
  DATABASE_URL=postgres://postgres:postgres@localhost:5432/ca_certs \
  DATABASE_SSL="false" \
  SECRET_KEY_BASE=""   \
  NERVES_HUB_CA_DIR="/app/test/ssl"

ADD . /app
WORKDIR /app

RUN mix local.hex --force && \
  mix local.rebar --force

RUN mix deps.get
RUN mix compile

EXPOSE 8443

# CMD ["iex", "-S", "mix", "phx.server"]
CMD ["iex", "-S", "mix"]


