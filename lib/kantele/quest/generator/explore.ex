defmodule Kantele.Quest.Generator.Explore do
  @moduledoc """
  探访任务模板（Q1-T3，LPC questd explore：到指定房间探访后回报委员）

  v1：单委员 NPC 发放任务（todo 登记 type/level），玩家按提示前往 target_room；
  完成报告的入位校验（须身在 target_room）待 Q2-T0 房间查询落地后接。
  """

  alias Kantele.Quest.Generator

  @type kind :: :explore

  def generate(opts) do
    with {:ok, zone} <- Generator.random_zone(opts),
         {:ok, officer} <- Generator.ok_or_error(Generator.random_officer(zone)),
         {:ok, target} <- Generator.ok_or_error(Generator.random_room(zone)) do
      {:ok, quest(zone.id, officer, target)}
    else
      _ -> {:error, :no_candidates}
    end
  end

  defp quest(zone_id, officer, target) do
    id = Generator.gen_id("explore")
    level = Generator.default_level()

    %{
      id: id,
      file: id,
      type: "explore",
      level: level,
      limit: Generator.default_limit(),
      officer_npc: officer.id,
      target_room: room_id(zone_id, target),
      item_id: nil,
      item_name: nil,
      count: 1,
      rewards: %{exp: 200, potential: 150, score: 15, weiwang: 5, coins: 100},
      prompt: "劳烦你走一趟#{room_name(target)}，认认路，回来与我说道说道。"
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