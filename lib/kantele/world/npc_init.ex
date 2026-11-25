defmodule Kantele.World.NpcInit do
  @moduledoc """
  逐 NPC 的 `init()` 反应派发（LPC `kungfu/class/ultra/*.c` 的 `init()`）。

  运行时由 `Kantele.Character.Events.MoveEvent.notice/2` 在玩家进屋时调用：
  房间内每个 NPC 都会收到 LPC 的 `init()`，其中大宗师做两件事——

  1. 无条件 `me->delete_temp("want_opinion")`：清掉玩家此前请求评价留下的意图
     （ex 侧为全部 `want_opinion/<key>` 键），经 `ultra/init` 事件投到玩家进程；
  2. `if (ultrap(me))` 时按各自逐字文案 `message_vision(...)`：
     独孤求败/黄裳微笑点头、霍山皱眉冷哼、葵花太监扫一眼冷笑。

  `ultrap/1` 在 LPC 是 `query("opinion/ultra")`（`adm/single/simul_efun/user.c:8`），
  不是 exp 阈值，因此这里读 `meta.env["opinion/ultra"]`，与
  `Kantele.NPC.Ultra.check_ultra/2` 写入的键一致。

  文案取自 NPC 的 `meta.ultra.msgs["init"]`（UCL 原样存放，无硬编码）；
  返回 `{:vision, text}` 交给 `MoveEvent` 广播，`:skip` 表示无反应。
  """

  alias Kalevala.Event

  @doc "玩家进屋时触发 NPC 的 init()；返回 `{:vision, 文案}` 或 `:skip`。"
  def init(npc, player) do
    case ultra_init(npc, player) do
      text when is_binary(text) and text != "" -> {:vision, text}
      _ -> :skip
    end
  end

  # 四位大宗师共用的 init() 骨架：先清意图（无条件），再按 ultrap 决定是否显文案。
  defp ultra_init(%{meta: %{ultra: cfg}} = _npc, player) when is_map(cfg) do
    notify_clear_intent(player)

    if ultrap?(player) do
      Map.get(Map.get(cfg, :msgs) || %{}, "init")
    else
      nil
    end
  end

  defp ultra_init(_npc, _player), do: nil

  # LPC `ultrap(ob) = ob->query("opinion/ultra")`（非 exp 门槛）。
  defp ultrap?(%{meta: %{env: env}}) when is_map(env) do
    truthy?(Map.get(env, "opinion/ultra") || Map.get(env, :"opinion/ultra"))
  end

  defp ultrap?(_), do: false

  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(0), do: false
  defp truthy?("0"), do: false
  defp truthy?("false"), do: false
  defp truthy?(_), do: true

  # NPC 进程不能直接改玩家 meta；发事件给玩家进程自己清。
  defp notify_clear_intent(%{pid: pid}) when is_pid(pid) do
    send(pid, %Event{
      from_pid: self(),
      topic: "ultra/init",
      data: %{clear_want_opinion: true}
    })
  end

  defp notify_clear_intent(_player), do: :ok
end
