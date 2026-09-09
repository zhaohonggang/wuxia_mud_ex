defmodule Kantele.World.MirrorDaemon.TaskCarrier do
  @moduledoc """
  宝镜任务载体 NPC（TaskCarrier）：
  - 随机 liuxi 非 no_fight 房间
  - 等级 1-15 随机，按级加强属性
  - 背包携带 1 个 task 物品
  - 无 loot、无重生、死亡即销毁
  """

  require Logger

  alias Kantele.Character.{NPCConfig, NonPlayerMeta, Stats, Vitals}
  alias Kantele.Character.Combat
  alias Kalevala.World.Item.Instance
  alias Kantele.World.Items

  @liuxi_zone "liuxi"

  @level_stats %{
    1  => %{qi: 8_000,  sk_lvl: 200, apply_mult: 1},
    2  => %{qi: 10_000, sk_lvl: 250, apply_mult: 1},
    3  => %{qi: 12_000, sk_lvl: 300, apply_mult: 1},
    4  => %{qi: 14_000, sk_lvl: 350, apply_mult: 1},
    5  => %{qi: 16_000, sk_lvl: 400, apply_mult: 1},
    6  => %{qi: 18_000, sk_lvl: 450, apply_mult: 1},
    7  => %{qi: 20_000, sk_lvl: 500, apply_mult: 1},
    8  => %{qi: 22_000, sk_lvl: 550, apply_mult: 1},
    9  => %{qi: 24_000, sk_lvl: 600, apply_mult: 1},
    10 => %{qi: 26_000, sk_lvl: 650, apply_mult: 1},
    11 => %{qi: 28_000, sk_lvl: 700, apply_mult: 1},
    12 => %{qi: 30_000, sk_lvl: 750, apply_mult: 1},
    13 => %{qi: 32_000, sk_lvl: 800, apply_mult: 1},
    14 => %{qi: 34_000, sk_lvl: 850, apply_mult: 1},
    15 => %{qi: 36_000, sk_lvl: 900, apply_mult: 1}
  }

  @doc "构建任务载体 NPC 角色结构（携带指定 task 物品）"
  def build_carrier(task_name, task_def, room_id) do
    level = :rand.uniform(15)
    level_stat = Map.get(@level_stats, level, Map.get(@level_stats, 1))

    sk_lvl = level_stat.sk_lvl
    qi = level_stat.qi
    jing = div(qi, 2)
    neili = div(qi * 8, 5)
    combat_exp = div(sk_lvl * sk_lvl * sk_lvl, 10) + :rand.uniform(1000 * level)

    # 创建 task 物品实例放入背包
    task_item_id = task_def.item_id
    task_instance = create_instance(task_item_id)

    meta =
      %NonPlayerMeta{
        zone_id: @liuxi_zone,
        initial_events: [],
        vitals: %Vitals{
          qi: qi,
          max_qi: qi,
          base_qi: qi,
          jing: jing,
          max_jing: jing,
          base_jing: jing,
          jingli: 0,
          max_jingli: 0,
          neili: neili * 2,
          max_neili: neili * 2,
          base_neili: neili * 2
        },
        stats: %Stats{
          str: 40,
          dex: 40,
          con: 35,
          int: 25,
          combat_exp: combat_exp,
          potential: 0,
          learned_points: 0,
          score: 0,
          weiwang: 0,
          gongxian: 0,
          shen: 0,
          skills: %{
            "unarmed" => sk_lvl,
            "dodge" => sk_lvl,
            "parry" => sk_lvl,
            "force" => sk_lvl
          },
          mapped: %{
            "force" => :xiyang_neigong,
            "dodge" => :xiyang_boji,
            "parry" => :xiyang_jian,
            "sword" => :xiyang_jian
          },
          performs: MapSet.new(),
          tattoo: nil,
          reborn: 0
        },
        combat_config: %NPCConfig{
          attitude: "passive",
          spawn_room_id: room_id,
          respawn_delay: 0,           # 任务 NPC 死后不重生
          no_kill: false,
          apply: %{"attack" => sk_lvl, "damage" => sk_lvl, "armor" => div(sk_lvl, 3)}
        },
        combat: Combat.new(),
        loot: [],                     # 任务物品在背包里，给予后销毁，无额外掉落
        goods: nil,
        inquiries: nil,
        teach: nil,
        turn_in: nil,
        quest: nil,
        coagents: [],
        parts: %{},
        no_cut: %{},
        default_clone: nil,
        been_cut: 0,
        defeated_by: nil
      }
      # 任务载体标记（用于死亡回调识别）
      |> Map.put(:kind, "task_carrier")
      |> Map.put(:task_name, task_name)
      |> Map.put(:task_item_id, task_def.item_id)

    %Kalevala.Character{
      id: "task-carrier-#{task_name}-#{System.unique_integer([:positive])}",
      name: task_def.owner,
      description: "一名路人模样的中年人，背着个布包，神色匆匆。",
      brain: %Kalevala.Brain{root: %Kalevala.Brain.NullNode{}},
      room_id: room_id,
      inventory: [task_instance],
      meta: meta
    }
  end

  defp create_instance(item_id) do
    %Instance{
      id: Instance.generate_id(),
      item_id: item_id,
      created_at: DateTime.utc_now()
    }
  end
end