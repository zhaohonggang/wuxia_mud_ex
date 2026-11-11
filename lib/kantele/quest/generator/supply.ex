defmodule Kantele.Quest.Generator.Supply do
  @moduledoc """
  供应任务模板（Q1-T3，LPC questd supply：收集指定数量装备/货物交给委员）

  v1：单委员 NPC 委托，count=3..8（`3 + random(6)`），逐件计数交付（`quest/turnin-request`
  校验背包物品，meta.count 累计，count=0 则结算）。`start_room` 用于入位门控。
  """

  alias Kantele.Quest.Generator

  @type kind :: :supply

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
    id = Generator.gen_id("supply")
    level = Generator.default_level()

    %{
      id: id,
      file: id,
      type: "supply",
      level: level,
      limit: Generator.default_limit(),
      officer_npc: officer.id,
      target_room: room_id(zone_id, target),
      start_room: room_id(zone_id, target),
      item_id: item_id,
      item_name: item_name,
      count: 3 + Generator.rand_between(0, 5),
      rewards: %{exp: 100, potential: 40, score: 15, coins: 150},
      prompt: "库房紧缺#{item_name}，你若寻得#{item_name}，尽快送来，我有重谢。"
    }
  end

  defp room_id(zone_id, room) do
    case Map.get(room, :id) do
      nil -> "#{zone_id}:unknown"
      id -> to_string(id)
    end
  end
end
