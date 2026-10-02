# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :ex_venture,
  namespace: Web,
  ecto_repos: [ExVenture.Repo]

config :ex_venture, :listener, start: true

# 机器人（data/bots/*.ucl）：压测/验收工具；开发环境可开启，测试环境关闭
config :ex_venture, :bots, enabled: true

# 出口阻挡条件（房间 valid_leave）是否真正拦截移动。默认关 —— 开启即行为变更，
# 需要逐区灰度。数据侧 183 条条件见 data/world/*/… 的 valid_leave.condition
# （由 scripts/migrate_exit_vetoes.py 从注释搬入），求值器见
# Kantele.World.LpcCondition（183 条里 171 条可执行，其余保留原文不拦）。
config :ex_venture, :enforce_exit_vetoes, false

# Configures the endpoint
config :ex_venture, Web.Endpoint,
  render_errors: [view: Web.ErrorView, accepts: ~w(html json)],
  pubsub_server: ExVenture.PubSub

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :porcelain, driver: Porcelain.Driver.Basic

if File.exists?("config/#{Mix.env()}.exs") do
  import_config "#{Mix.env()}.exs"
end
