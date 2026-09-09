defmodule Kantele.World.Invasion.NPC do
  @moduledoc """
  入侵 NPC 统一构建器 + 3 国族配置（LPC invasion/npc/*.c 对齐）。

  属性公式（来自 LPC set_invader_skill）：
  - sk_lvl = level * 50 + 200 + random(50)  （L1~L5 对应 180/300/400/450/500 ± 随机）
  - combat_exp = sk_lvl^3 / 10 + random(1000 * level)
  - qi: L1=10000, L2=15000, L3=18000, L4=20000, L5=30000
  - jing = qi / 2
  - neili = qi * 8 / 5
  - jiali = force_skill / 2
  - 头衔/称号按 level
  """

  require Logger

  alias Kantele.Character.{NPCConfig, NonPlayerMeta, Stats, Vitals}
  alias Kantele.Character.Combat
  alias Kantele.World.Items

  @liuxi_zone "liuxi"

  # 国族武器/技能映射（对应 LPC english/european/japanese.c）
  @nation_config %{
    japanese: %{
      weapon: "liuxi:weapon/jpn-dao",
      armor: "liuxi:cloth/cloth",
      skills: %{"force" => :fushang_neigong, "dodge" => :renshu, "parry" => :dongyang_dao, "blade" => :dongyang_dao},
      skill_names: %{"force" => "扶桑内功", "dodge" => "忍术", "parry" => "东阳刀", "blade" => "东阳刀"},
      nickname: "倭寇刀客"
    },
    english: %{
      weapon: "liuxi:weapon/qishiji",
      armor: "liuxi:cloth/yinjia",
      skills: %{"force" => :xiyang_neigong, "dodge" => :xiyang_boji, "parry" => :qishi_ji, "club" => :qishi_ji},
      skill_names: %{"force" => "西洋内功", "dodge" => "西洋拨击", "parry" => "骑士技", "club" => "骑士技"},
      nickname: "英夷棍僧"
    },
    european: %{
      weapon: "liuxi:weapon/xiyang-sword",
      armor: "liuxi:cloth/cloth",
      skills: %{"force" => :xiyang_neigong, "dodge" => :xiyang_boji, "parry" => :xiyang_jian, "sword" => :xiyang_jian},
      skill_names: %{"force" => "西洋内功", "dodge" => "西洋拨击", "parry" => "西洋剑", "sword" => "西洋剑"},
      nickname: "西洋剑士"
    }
  }

  # 级别基础属性（LPC set_invader_skill switch）
  @level_stats %{
    1 => %{qi: 10_000, sk_base: 180, sk_rand: 10, rank: "小喽啰", title: "入侵小喽啰"},
    2 => %{qi: 15_000, sk_base: 300, sk_rand: 50, rank: "小头目", title: "入侵小头目"},
    3 => %{qi: 18_000, sk_base: 400, sk_rand: 50, rank: "大头目", title: "入侵大头目"},
    4 => %{qi: 20_000, sk_base: 450, sk_rand: 50, rank: "高级将领", title: "入侵高级将领"},
    5 => %{qi: 30_000, sk_base: 500, sk_rand: 50, rank: "最高统帅", title: "入侵最高统帅"}
  }

  @doc "构建入侵 NPC 角色结构（同 Challenger.build_character 路径）"
  def build_invader(nation, level, number, room_id) do
    nation_cfg = Map.get(@nation_config, nation, Map.get(@nation_config, :japanese))
    level_stat = Map.get(@level_stats, level, Map.get(@level_stats, 1))

    sk_lvl = level * 50 + 200 + :rand.uniform(50)
    combat_exp = div(sk_lvl * sk_lvl * sk_lvl, 10) + :rand.uniform(1000 * level)
    qi = level_stat.qi
    jing = div(qi, 2)
    neili = div(qi * 8, 5)
    jiali = div(sk_lvl, 2)

    # 技能：每级 +20 差值
    skills = Map.new(nation_cfg.skills, fn {k, _v} -> {k, sk_lvl} end)

    name = "#{nation_cfg.nickname}-#{number}"

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
          shen: -1000,
          skills: skills,
          mapped: %{
            "force" => nation_cfg.skills.force,
            "dodge" => nation_cfg.skills.dodge,
            "parry" => nation_cfg.skills.parry
          },
          performs: MapSet.new(),
          tattoo: nil,
          reborn: 0
        },
        combat_config: %NPCConfig{
          attitude: "aggressive",
          spawn_room_id: room_id,
          respawn_delay: 0,
          no_kill: false,
          apply: %{"attack" => sk_lvl, "damage" => sk_lvl, "armor" => div(sk_lvl, 3)}
        },
        combat: Combat.new(),
        loot: ["liuxi:misc/xuantie-ling"],
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
      # 入侵 NPC 标记（用于死亡回调识别）
      |> Map.put(:kind, "invader")
      |> Map.put(:invader_number, number)

    %Kalevala.Character{
      id: "invasion-#{number}-#{System.unique_integer([:positive])}",
      name: name,
      description: "一名#{nation_cfg.nickname}，杀气腾腾，显然是来寻仇的。",
      brain: %Kalevala.Brain{root: %Kalevala.Brain.NullNode{}},
      room_id: room_id,
      meta: meta
    }
  end

  # 供 NPC 进程内部调用：获取本国族的 weapon/armor item_id（用于 NPC 初始化后穿戴）
  def nation_weapon(nation), do: Map.get(@nation_config, nation, %{})[:weapon]
  defp nation_armor(nation), do: Map.get(@nation_config, nation, %{})[:armor]

  def nation_skill_atoms(nation) do
    Map.get(@nation_config, nation, %{})[:skills]
    |> Map.keys()
  end
end