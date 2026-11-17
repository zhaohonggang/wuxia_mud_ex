defmodule Kantele.World.ShaolinPromotionAccept do
  @moduledoc """
  少林辈分晋升的 `accept_object/2`（LPC `qing.h` / `cheng.h` / `hui.h` / `dao.h` /
  `xuan.h`）：玩家交来达摩令或推荐信时，NPC 进程只识别规则并转交玩家进程。

  玩家 `meta.temp` 与背包只能在玩家进程写，所以沿用 `HunterAccept` /
  `SuoyangdanAccept` 的成熟模式：NPC 侧命中 UCL `accept` 规则后发
  `shaolin_promotion/give`，玩家侧执行门控与副作用，再用
  `shaolin_promotion/give-result` 回执让 NPC 说出 LPC 原版台词。
  """

  alias Kalevala.Event
  alias Kantele.Character.CommandView

  import Kalevala.Character.Conn, only: [put_character: 2, render: 4, prompt: 4]

  def handle(conn, npc, item_instance, data, from_name, rule) do
    send(
      Map.get(data, :reply_to),
      %Event{
        from_pid: self(),
        topic: "shaolin_promotion/give",
        data: %{
          rule: rule,
          item_id: item_instance.item_id,
          instance_id: item_instance.id,
          from_id: Map.get(data, :from_id),
          from_name: from_name,
          npc_id: npc.id,
          npc_name: npc.name,
          room_id: npc.room_id,
          reply_to: self()
        }
      }
    )

    conn
    |> put_character(npc)
    |> render(CommandView, "text", %{
      text: "#{npc.name}接过#{item_name(item_instance)}，看了看。\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end

  defp item_name(%{item_id: item_id}) do
    case Kantele.World.Items.get(item_id) do
      {:ok, item} -> item.name
      _ -> "物品"
    end
  end
end
