defmodule Kantele.World.XiakedaoHiredHelper do
  @moduledoc """
  #801 把 LPC `new(class/generate/helper)` 生成的侠客岛随从落成真实 NPC 进程。

  LPC `renter.c:299-330` 先按 `npc_level` 生成 helper（`init_npc_skill` 按
  `npcd.c levels` 给定 combat_exp / 技能等级，`init_man` 按 life/neili 表给血量），
  雇用后再 `move(environment())` + `set_leader(me)` + `keep_heart_beat()`。

  Ex 侧按同一张表构造 `%Kalevala.Character{}` 并走 `Kantele.World.Story.Challenger`
  已经在用的 `Kalevala.World.start_character/2` + `SpawnController` 路径，
  出生房间即玩家所在房间；随后由 `GiveEvent.xiakedao_rent_returned/2`
  发 `follow/set-leader` / `follow/register` 建立真实跟随关系。
  """

  alias Kalevala.Brain
  alias Kalevala.Character
  alias Kantele.Character.Combat
  alias Kantele.Character.NPCConfig
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  # 与 renter.c:15-91 info 表、npcd.c levels 表逐项对齐。
  @life [500, 800, 1000, 1200, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000, 6000, 7000, 8000]
  @neili [800, 1000, 1200, 1600, 2000, 2500, 3000, 3500, 4000, 5000, 6000, 7000, 8000, 9000, 9999]
  @skill_level [20, 30, 40, 50, 120, 150, 175, 200, 225, 250, 275, 300, 350, 400, 450]

  @doc "按 helper 描述 + 房间生成真实 NPC；失败时返回 `{:error, reason}`"
  def spawn(helper, room_id, opts \\ []) do
    case Keyword.get(opts, :spawn_hook) do
      fun when is_function(fun, 2) ->
        {:ok, fun.(helper, room_id)}

      _ ->
        with {:ok, zone_id} <- room_zone_id(room_id),
             character <- build_character(helper, room_id, zone_id),
             {:ok, pid} <- start_character(character, zone_id) do
          {:ok, %{id: character.id, name: character.name, pid: pid, room_id: room_id}}
        end
    end
  end

  defp build_character(helper, room_id, zone_id) do
    level = normalize_level(Map.get(helper, "npc_level") || Map.get(helper, :npc_level))
    name = Map.get(helper, "name") || Map.get(helper, :name) || "侠客岛弟子"
    id = Map.get(helper, "id") || Map.get(helper, :id) || "xiakedao_helper"
    exp = Map.get(helper, "combat_exp") || Enum.at(@skill_level, level - 1) * 1000
    skill = Enum.at(@skill_level, level - 1)
    life = Enum.at(@life, level - 1)
    neili = Enum.at(@neili, level - 1)

    %Character{
      id: "xiakedao_helper:#{id}",
      name: name,
      description: "一名侠客岛弟子，受黄衣使者之托前来助拳。",
      brain: %Brain{root: %Brain.NullNode{}},
      room_id: room_id,
      meta: %NonPlayerMeta{
        zone_id: zone_id,
        initial_events: [],
        vitals: %Vitals{
          qi: life,
          max_qi: life,
          base_qi: life,
          jing: div(life, 2),
          max_jing: div(life, 2),
          base_jing: div(life, 2),
          jingli: div(neili, 4),
          max_jingli: div(neili, 4),
          neili: neili,
          max_neili: neili,
          base_neili: neili
        },
        stats: %Stats{
          str: 20 + level,
          dex: 20 + level,
          con: 20 + level,
          int: 20,
          combat_exp: exp,
          skills: %{
            "force" => skill,
            "unarmed" => skill,
            "dodge" => skill,
            "parry" => skill
          },
          mapped: %{},
          performs: MapSet.new()
        },
        combat_config: %NPCConfig{
          attitude: "friendly",
          spawn_room_id: room_id,
          respawn_delay: nil,
          no_kill: false,
          apply: %{"damage" => 15, "armor" => 100, "attack" => skill}
        },
        combat: Combat.new(),
        family: %{name: "侠客岛"},
        aliases: [id, name],
        coagents: [],
        carry: []
      }
    }
  end

  defp normalize_level(level) when is_integer(level) and level >= 1 and level <= 15, do: level

  defp normalize_level(level) when is_binary(level) do
    case Integer.parse(level) do
      {value, _} -> normalize_level(value)
      :error -> 1
    end
  end

  defp normalize_level(_level), do: 1

  defp room_zone_id(room_id) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) ->
        case Map.get(:sys.get_state(pid), :data) do
          %{zone_id: zone_id} when is_binary(zone_id) -> {:ok, zone_id}
          _ -> {:error, {:no_zone_id, room_id}}
        end

      _ ->
        {:error, {:room_not_running, room_id}}
    end
  end

  defp start_character(character, zone_id) do
    Kalevala.World.start_character(character,
      supervisor_name: Kalevala.World.CharacterSupervisor.global_name(zone_id),
      communication_module: Kantele.Communication,
      initial_controller: Kantele.Character.SpawnController,
      quit_view: {Kantele.Character.QuitView, "disconnected"}
    )
  end
end
