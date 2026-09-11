# 机器人控制脚本（压测/验收工具）：连接运行节点后启停/查询机器人。
#
# 用法（与 scripts/boar_dump.exs 同架构，宿主机执行）：
#   mix run scripts/bots.exs status
#   mix run scripts/bots.exs start grinder
#   mix run scripts/bots.exs stop grinder
# 若游戏跑在 docker 容器里，先在本机把源码拷进容器再跑，
# 或利用 :rpc 的 node 连接（容器 sname 需可发现，见 boar_dump.exs）。
defmodule Bots.Ctl do
  def run() do
    {:ok, hostname} = :inet.gethostname()
    node = String.to_atom("app@#{hostname}")
    true = Node.connect(node)

    [action | rest] = args()

    case {action, rest} do
      {"status", []} ->
        :rpc.block_call(node, Code, :eval_string, [status_code(), [], [file: "bot_status"]])

      {"start", [name]} ->
        :rpc.block_call(node, Code, :eval_string, [start_code(name), [], [file: "bot_start"]])

      {"stop", [name]} ->
        :rpc.block_call(node, Code, :eval_string, [stop_code(name), [], [file: "bot_stop"]])

      _ ->
        IO.puts("usage: mix run scripts/bots.exs status|(start|stop) <key>")
    end
  end

  defp args do
    System.argv()
  end

  defp status_code do
    ~S"""
    Kantele.Bot.Registry.status()
    |> Enum.each(fn %{config: cfg} = s ->
      run = if s.running, do: inspect(s.stats), else: "down"
      IO.puts("bot #{cfg.key} name=#{cfg.name} enabled=#{cfg.enabled} -> #{run}")
    end)
    """
  end

  defp start_code(name) do
    "IO.puts(inspect(Kantele.Bot.Registry.start(\"#{name}\")))"
  end

  defp stop_code(name) do
    "IO.puts(inspect(Kantele.Bot.Registry.stop(\"#{name}\")))"
  end
end

Bots.Ctl.run()