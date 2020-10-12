use Mix.Config

config :nerves_hub_ca, NervesHubCA.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: System.get_env("DATABASE_URL"),
  database: "ca_certs",
  ssl: true
