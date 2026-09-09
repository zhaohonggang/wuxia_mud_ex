defmodule Kantele.Quest.Generator.Search do
  @moduledoc """
  寻物任务模板（Q1-T3，LPC questd search：宝物藏入房间 search_objects，寻得后交回委员）

  v1：单委员 NPC 发放任务（todo 登记 type/level），玩家按提示往 target_room 搜寻；
  完成报告的入位校验（须身在藏宝房）待 Q2-T0 房间查询落地后接，见 §15 Q1-T3 风险。
  """

  alias Kantele.Quest.Generator

  @type kind :: :search

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
    id = Generator.gen_id("search")
    level = Generator.default_level()

    %{
      id: id,
      file: id,
      type: "search",
      level: level,
      limit: Generator.default_limit(),
      officer_npc: officer.id,
      target_room: room_id(zone_id, target),
      item_id: item_id,
      item_name: item_name,
      count: 1,
      rewards: %{exp: 200, potential: 150, score: 30, weiwang: 1, coins: 100},
      prompt: "听说#{room_name(target)}落下一件#{item_name}，你替我去找找，寻着了便回来告诉我。"
    }
  end

  defp room_id(zone_id, room) do
    case Map.get(room, :id) do
      nil -> "#{zone_id}:unknown"
      id -> to_string(id)
    end
  end

  defp room_name(room) do
    case Map.get(room, :name) do
      nil -> "一处地方"
      name -> to_string(name)
    end
  end
end