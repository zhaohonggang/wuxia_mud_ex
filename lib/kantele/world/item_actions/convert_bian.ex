defmodule Kantele.World.ItemActions.ConvertBian do
  @moduledoc """
  灵蛇杖/蛇杖 `convert` 动作（物品动作通道，第十二批扩展）。

  对应 LPC `lingshezhang.c` / `shezhang.c` 的 `do_convert`：

      int do_convert()
      {
          if (this_player()->query("family/family_name") != "欧阳世家")
              return notify_fail("只有欧阳世家的人才能使用灵蛇杖化蛇。\n");
          if (this_player()->query("jing") < 100)
              return notify_fail("你的精力不够，无法施展化蛇之术。\n");
          if (this_player()->query_skill("training") < 70 + random(70))
              return notify_fail("你的驯兽术不够高明，无法控制灵蛇。\n");
          new("/d/baituo/npc/lingshe")->move(environment(this_player()));
          destruct(this_object());
      }

  handler 名（对应 UCL `items.meta.actions[].handler`）：
  - `convert_lingshe`（灵蛇杖）→ 生成 `lingshe` NPC（key "lingshe"）
  - `convert_snake`（蛇杖）→ 生成 `snake` NPC（key "snake"）

  成功后：在玩家当前房间 spawn 对应 NPC，从玩家背包移除法杖（destruct 等价），
  向房间广播化蛇文案。
  """
  use Kantele.World.ItemAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.Family
  alias Kantele.Character.Stats
  alias Kantele.World.RoomActions.Helpers, as: RoomHelpers

  # handler 名 → UCL characters 块 key
  @npc_key %{
    "convert_lingshe" => "lingshe",
    "convert_snake" => "snake"
  }

  # handler 名 → NPC 中文名（广播文案用）
  @npc_cname %{
    "convert_lingshe" => "灵蛇",
    "convert_snake" => "毒蛇"
  }

  @impl true
  def run(conn, %{handler: handler, item: item, instance: instance, room_id: room_id}) do
    npc_key = Map.get(@npc_key, handler)

    cond do
      is_nil(npc_key) ->
        :not_handled

      not family_ok?(conn) ->
        render(conn, "只有欧阳世家的弟子才能施展化蛇之术。\n")

      not jing_ok?(conn) ->
        render(conn, "你的精力不足，无法施展化蛇之术。\n")

      not training_ok?(conn) ->
        render(conn, "你的驯兽术不够高明，无法控制灵蛇。\n")

      true ->
        do_convert(conn, handler, npc_key, item, instance, room_id)
    end
  end

  defp do_convert(conn, _handler, npc_key, item, instance, room_id) do
    character = current(conn)

    npc = build_npc(npc_key, room_id)

    config = [
      supervisor_name: Kalevala.World.CharacterSupervisor.global_name("baituo"),
      communication_module: Kantele.Communication,
      initial_controller: Kantele.Character.SpawnController,
      quit_view: {Kantele.Character.QuitView, "disconnected"}
    ]

    case Kalevala.World.start_character(npc, config) do
      {:ok, _pid} ->
        cname = Map.get(@npc_cname, handler_for(npc_key))

        conn =
          conn
          |> RoomHelpers.broadcast_vision(
            room_id,
            "#{item.name}化作一#{cname}，#{cname_verb(cname)}在地上蜿蜒游动。\n"
          )

        # destruct 等价：从背包移除该法杖实例
        new_inventory =
          Enum.reject(character.inventory, fn inst -> inst.id == instance.id end)

        conn
        |> put_character(%{character | inventory: new_inventory})
        |> render("你手中的#{item.name}化作一#{cname}，#{cname_verb(cname)}游走了。\n")

      {:error, _reason} ->
        render(conn, "化蛇之术施展失败，灵蛇未能现形。\n")
    end
  end

  # ---- guards -----------------------------------------------------------

  defp family_ok?(conn) do
    character = current(conn)
    family = Map.get(character.meta, :family)
    is_map(family) and Family.name(family) == "欧阳世家"
  end

  defp jing_ok?(conn) do
    character = current(conn)
    jing = Map.get(character.meta.vitals, :jing, 0)
    is_integer(jing) and jing >= 100
  end

  defp training_ok?(conn) do
    character = current(conn)
    stats = character.meta.stats
    level = case stats do
      %Kantele.Character.Stats{} -> Stats.skill(stats, "training")
      _ -> 0
    end
    level >= 70 + :rand.uniform(70)
  end

  # ---- helpers ----------------------------------------------------------

  defp handler_for("lingshe"), do: "convert_lingshe"
  defp handler_for("snake"), do: "convert_snake"
  defp handler_for(_), do: nil

  defp cname_verb("灵蛇"), do: "尾部银鳞闪闪"
  defp cname_verb("毒蛇"), do: "尾巴沙沙作响"
  defp cname_verb(_), do: "在地上游动"

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character

  defp render(conn, text) when is_binary(text) do
    RoomHelpers.render_to_player(conn, text)
  end

  # ---- NPC 构建 ----------------------------------------------------------

  defp build_npc("lingshe", room_id) do
    %Kalevala.Character{
      id: "lingshe-#{System.unique_integer([:positive])}",
      name: "灵蛇",
      description: "一条银光闪闪的小蛇，产于西域，极为罕见。",
      brain: %Kalevala.Brain{root: %Kalevala.Brain.NullNode{}},
      room_id: room_id,
      inventory: [],
      meta: %Kantele.Character.NonPlayerMeta{
        zone_id: "baituo",
        init: %{add_actions: ["bian"], greet_delay: 0},
        stats: %Kantele.Character.Stats{
          combat_exp: 100_000,
          skills: %{"unarmed" => 40, "dodge" => 50}
        },
        vitals: %Kantele.Character.Vitals{
          qi: 500,
          max_qi: 500,
          base_qi: 500,
          jing: 250,
          max_jing: 250,
          base_jing: 250
        },
        combat_config: %Kantele.Character.NPCConfig{
          attitude: "peaceful",
          spawn_room_id: room_id
        },
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp build_npc("snake", room_id) do
    %Kalevala.Character{
      id: "snake-#{System.unique_integer([:positive])}",
      name: "毒蛇",
      description: "一只有着三角形脑袋的蛇，尾巴沙沙做响。",
      brain: %Kalevala.Brain{root: %Kalevala.Brain.NullNode{}},
      room_id: room_id,
      inventory: [],
      meta: %Kantele.Character.NonPlayerMeta{
        zone_id: "baituo",
        init: %{add_actions: ["bian"], greet_delay: 0},
        stats: %Kantele.Character.Stats{
          combat_exp: 1000,
          skills: %{"unarmed" => 30, "dodge" => 40}
        },
        vitals: %Kantele.Character.Vitals{
          qi: 200,
          max_qi: 200,
          base_qi: 200,
          jing: 100,
          max_jing: 100,
          base_jing: 100
        },
        combat_config: %Kantele.Character.NPCConfig{
          attitude: "peaceful",
          spawn_room_id: room_id
        },
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp build_npc(_key, _room_id), do: nil
end
