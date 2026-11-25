defmodule Kantele.World.UltraAccept do
  @moduledoc """
  大宗师绝招 quest 的 `accept_object`（对应 dugu.c / huang.c）。

  - 独孤求败：`dugubook`（独孤九剑残本）→ 340 独孤九剑 + 悟性/根骨门 →
    `can_learn/dugu-jiujian/nothing=1` + 大量练功。
  - 黄裳：`zhenjing1` / `zhenjing2`（九阴真经上下册）→ 集齐两册置
    `can_learn/jiuyin-shengong/xin=1`，随后 `ask 摄心大法` 才传绝招。

  NPC 侧只做「收不收 + 台词」，玩家侧的 flag/奖励落定在
  `Kantele.Character.GiveEvent.ultra_give_item/2`（跨进程，仅玩家进程可改自己）。
  """

  alias Kalevala.Event
  alias Kantele.Character.CommandView

  import Kalevala.Character.Conn, only: [put_character: 2, render: 4, prompt: 4]

  def handle(conn, npc, item_instance, data, from_name, rule) do
    reply_to = Map.get(data, :reply_to)
    quest = Map.get(rule || %{}, :action)

    send(reply_to, %Event{
      from_pid: self(),
      topic: "ultra/give-item",
      data: %{
        quest: quest,
        item_id: item_instance.item_id,
        instance_id: item_instance.id,
        from_name: from_name,
        npc_name: npc.name
      }
    })

    conn
    |> put_character(npc)
    |> render(CommandView, "text", %{text: accept_text(quest) <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp accept_text("dugubook"), do: "不错，不错！既然如此，我就将独孤九剑之精髓传授于你。"
  defp accept_text("zhenjing1"), do: "很好，很好！还有一本「九阴真经下册」，你尽快找到交还与我！"
  defp accept_text("zhenjing2"), do: "很好，很好！还有一本「九阴真经上册」，你尽快找到交还与我！"
  defp accept_text(_), do: "你给我这种东西干什么？"
end
