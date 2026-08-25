use Mix.Config

#
# If you're looking to update variables, you probably want to:
# - Edit `.env.test`
# - Add to `ExVenture.Config` for loading through Vapor
#

# Configure your database
# 固定连测试库（Repo.init 会优先采用这里设置的 url）。
# 注意：不要读 DATABASE_URL 环境变量——容器/compose 里该变量指向 dev 库，
# 读了会让测试误连开发库
config :ex_venture, ExVenture.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  url: "postgresql://postgres:postgres@db/ex_venture_test"

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ex_venture, Web.Endpoint,
  http: [port: 4002],
  server: false

config :ex_venture, ExVenture.Mailer, adapter: Bamboo.TestAdapter

config :ex_venture, :listener, start: false

# 单元测试不播种世界（战斗公式测试为纯函数；世界数据由 loader 测试按需加载）
config :ex_venture, :kantele_world, kickoff: false

# Print only warnings and errors during test
config :logger, level: :warn

config :bcrypt_elixir, :log_rounds, 4

config :stein_storage, backend: :test
