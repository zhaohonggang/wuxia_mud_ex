# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ex_venture,
  namespace: Web,
  ecto_repos: [ExVenture.Repo]

config :ex_venture, :listener, start: true

# 机器人（data/bots/*.ucl）：压测/验收工具；开发环境可开启，测试环境关闭
config :ex_venture, :bots, enabled: true

# 出口阻挡条件（房间 valid_leave）是否真正拦截移动。
# 打开前请看 docs/ucl-comment-implementation-plan.zh-CN.md §2 与
# lib/kantele/world/lpc_condition.ex 的 moduledoc：
#   - 数据侧 166 条条件（43 个区），其中 148 条可执行
#   - 求值器解析不了/求值失败一律放行（宁可少拦，不能把玩家锁死在房里）
#   - 另 18 条是 check_dirs/check_out/ob->refuse 三种自定义函数形态，未实现
# 改本项需重启应用（config.exs 是编译期读取）。
config :ex_venture, :enforce_exit_vetoes, true

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

# 自定义锻造物品模板的落盘目录（`Kantele.World.ForgeTemplates`）。
# 启动时会把该目录下所有 `*.json` 灌回 `Kantele.World.Items`。
config :ex_venture, :forge_dir, "data/forge"

# 锻造链 `call_out` 定时的秒数缩放（`Kantele.World.ForgingTimeout`）。
# 1 = 真实时间（开炉 1s、注内力窗口 6s、报价超时 30s、起名等待 240s…）。
config :ex_venture, :forge_timing_scale, 1

if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
