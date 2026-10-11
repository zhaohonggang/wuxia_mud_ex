defmodule Kantele.Combat.Skills.LanshaShou do
  @moduledoc """
  武学实装「lansha-shou」（源 lansha-shou.c，由 translate_skill.exs 生成）

  已自动化：静态招式 9 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/lansha_shou/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N跨前一步，双掌陡然攻出，带着丝丝阴风击向$n的$l",
      "force" => 100,
      "attack" => 25,
      "parry" => 20,
      "dodge" => 15,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左掌护胸，右掌掌心带着极寒之气拍向$n的$l",
      "force" => 130,
      "attack" => 30,
      "parry" => 15,
      "dodge" => 10,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N双掌拍出满天阴风，忽然右掌悄无声息的拍向$n的$l",
      "force" => 180,
      "attack" => 50,
      "parry" => 30,
      "dodge" => 20,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N怪叫一声，身形一跃，左掌快若疾电般击向$n的$l",
      "force" => 210,
      "attack" => 65,
      "parry" => 20,
      "dodge" => 25,
      "damage" => 35,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N阴笑一声，双掌一错，右掌忽然暴长数尺击向$n的$l",
      "force" => 210,
      "attack" => 65,
      "parry" => 20,
      "dodge" => 25,
      "damage" => 35,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N身形急晃，一跃而至$n跟前，右掌带着冲天寒气击向$n的$l",
      "force" => 210,
      "attack" => 65,
      "parry" => 20,
      "dodge" => 25,
      "damage" => 35,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N仰天长啸，双掌掌风似千古不化的寒冰般扑向$n的$l",
      "force" => 210,
      "attack" => 65,
      "parry" => 20,
      "dodge" => 25,
      "damage" => 35,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N身法陡然一变，掌影千变万幻，令$n无法躲闪",
      "force" => 250,
      "attack" => 45,
      "parry" => 20,
      "dodge" => 15,
      "damage" => 25,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N仰天一声狂啸，双掌携带着万古冰坚直直贯向$n",
      "force" => 330,
      "attack" => 35,
      "parry" => 20,
      "dodge" => 25,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "lansha-shou"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 40, neili: 60}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "po" => Kantele.Combat.Skills.Performs.LanshaShou.Po
    }
  end
end
