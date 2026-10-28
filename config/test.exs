import Config

#
# If you're looking to update variables, you probably want to:
# - Edit `.env.test`
# - Add to `ExVenture.Config` for loading through Vapor
#

# Configure your database
# 权威运行环境是容器（见 AGENTS.md），Windows 原生只是辅助。
# 默认值给宿主机用：compose 把 db 的 5432 映射到宿主 15432。
# 容器内**没有** localhost:15432，所以在容器里跑测试必须显式传 TEST_DATABASE_URL：
#   docker compose -f docker-compose.dev.yml run --rm -e MIX_ENV=test \
#     -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test app mix test
# 注意：**不要**读 DATABASE_URL —— compose 里它指向 dev 库，读了会让测试误连开发库。
config :ex_venture, ExVenture.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  url:
    System.get_env("TEST_DATABASE_URL") ||
      "postgresql://postgres:postgres@localhost:15432/ex_venture_test"

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ex_venture, Web.Endpoint,
  http: [port: 4002],
  server: false

config :ex_venture, ExVenture.Mailer, adapter: Bamboo.TestAdapter

config :ex_venture, :listener, start: false

# 测试环境不起机器人（它们会登录真实世界并打怪）
config :ex_venture, :bots, enabled: false

# 单元测试不播种世界（战斗公式测试为纯函数；世界数据由 loader 测试按需加载）
config :ex_venture, :kantele_world, kickoff: false

# Print only warnings and errors during test
config :logger, level: :warn

config :bcrypt_elixir, :log_rounds, 4

config :stein_storage, backend: :test

# 锻造模板落盘目录：指到 tmp 下，避免测试把 `data/forge/*.json` 写进仓库。
# 具体用例需要真落盘时用 `Application.put_env(:ex_venture, :forge_dir, ...)` 覆盖。
config :ex_venture, :forge_dir, "tmp/forge_test"

# 锻造定时器：测试里全部立即投递（`assert_receive` 拿到事件后手动驱动下一跳），
# 否则 `注内力` 的 6 秒窗口、报价 30 秒超时这些用例会真等上几分钟。
config :ex_venture, :forge_timing_scale, 0
