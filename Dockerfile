FROM elixir:alpine

WORKDIR /nerves_hub_ca

ENV MIX_ENV=prod

# install git and build-base
RUN apk --update add git openssh && \
  rm -rf /var/lib/apt/lists/* && \
  rm /var/cache/apk/*
RUN apk add build-base
RUN apk add bash
RUN apk add --no-cache make gcc libc-dev
RUN apk add inotify-tools

ADD . /app
WORKDIR /app

RUN mix local.hex --force && \
  mix local.rebar --force

RUN mix deps.get
RUN mix compile

CMD ["iex", "-S", "mix"]
