defmodule Kantele.Quest.Generator.Deliver do
  @moduledoc """
  送货任务模板（Q1-T3，LPC questd deliver：NPC2 取货 → 交 NPC1）

  v1：单委员 NPC 委托；玩家取得货物（商店购/打怪掉落等）后回到委员处
  交付——NPC 问话走 `quest/turnin-request`，玩家侧校验背包物品并结算
  （复用 A11/N6 turn_in 通路，无需 todo 登记）。
  """

  alias Kantele.Quest.Generator

  @type kind :: :deliver

  def generate(opts) do
    with {:ok, zone} <- Generator.random_zone(opts),
         {:ok, officer} <- Generator.ok_or_error(Generator.random_officer(zone)),
         {:ok, target} <- Generator.ok_or_error(Generator.random_room(zone)),
         {:ok, {item_id, item_name}} <- Generator.ok_or_error(Generator.random_item(opts)) do
      {:ok, quest(zone.id, officer, target, item_id, item_name)}
    else
      _ -> {:error, :no_candidates}
    end
  end

  defp quest(zone_id, officer, target, item_id, item_name) do
    id = Generator.gen_id("deliver")
    level = Generator.default_level()

    %{
      id: id,
      file: id,
      type: "deliver",
      level: level,
      limit: Generator.default_limit(),
      officer_npc: officer.id,
      target_room: room_id(zone_id, target),
      item_id: item_id,
      item_name: item_name,
      count: 1,
      rewards: %{exp: 150, potential: 60, score: 20, coins: 100},
      prompt: "有客商托我把#{item_name}送到别处，你若愿跑一趟，取了货便回来交差。"
    }
  end

  defp room_id(zone_id, room) do
    case Map.get(room, :id) do
      nil -> "#{zone_id}:unknown"
      id -> to_string(id)
    end
  end
end