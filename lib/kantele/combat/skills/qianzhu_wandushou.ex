defmodule Kantele.Combat.Skills.QianzhuWandushou do
  @moduledoc """
  武学实装「qianzhu-wandushou」（源 qianzhu-wandushou.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/qianzhu_wandushou/
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.PoisonHit

  @actions [
    %{
      "action" => "$N身形一晃而至，一招「小鬼勾魂」，双掌带着一缕腥风拍向$n的前心",
      "force" => 100,
      "attack" => 25,
      "parry" => 20,
      "dodge" => 15,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N身形化做一缕轻烟绕着$n急转，一招「天网恢恢」，双掌幻出无数掌影罩向$n",
      "force" => 130,
      "attack" => 30,
      "parry" => 15,
      "dodge" => 10,
      "damage" => 20,
      "lvl" => 30,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N怪叫一声，一招「阴风怒号」，双掌铺天盖地般拍向$n的$l",
      "force" => 160,
      "attack" => 45,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 25,
      "lvl" => 60,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一照「凄雨冷风」，双掌拍出满天阴风，忽然右掌悄无声息的拍向$n的$l",
      "force" => 180,
      "attack" => 50,
      "parry" => 30,
      "dodge" => 20,
      "damage" => 30,
      "lvl" => 80,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N大喝一声，一招「恶鬼推门」，单掌如巨斧开山带着一股腥风猛劈向$n的面门",
      "force" => 210,
      "attack" => 65,
      "parry" => 20,
      "dodge" => 25,
      "damage" => 35,
      "lvl" => 100,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一声冷笑，一招「灵蛇九转」，身形一闪而至，一掌轻轻拍出，手臂宛若无骨，掌到中途竟连\\n",
      "force" => 280,
      "attack" => 95,
      "parry" => 25,
      "dodge" => 25,
      "damage" => 45,
      "lvl" => 120,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N侧身向前，一招「地府阴风」，双掌连环拍出，一缕缕彻骨的寒气从掌心透出，将$n周围的空\\n",
      "force" => 320,
      "attack" => 110,
      "parry" => 30,
      "dodge" => 30,
      "damage" => 60,
      "lvl" => 140,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N厉叫一声，身形忽的蜷缩如球，飞身撞向$n，一招「黄蜂吐刺」单掌如剑，直刺$n的心窝",
      "force" => 360,
      "attack" => 135,
      "parry" => 35,
      "dodge" => 30,
      "damage" => 75,
      "lvl" => 160,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一个急旋，飞身纵起，半空中一式「毒龙摆尾」，反手击向$n的$l",
      "force" => 420,
      "attack" => 150,
      "parry" => 75,
      "dodge" => 30,
      "damage" => 90,
      "lvl" => 180,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N大喝一声，运起五毒神功，一招「毒火焚身」，刹那间全身毛发尽绿，一对碧绿的双爪闪电般的朝\\n",
      "force" => 450,
      "attack" => 185,
      "parry" => 80,
      "dodge" => 40,
      "damage" => 120,
      "lvl" => 200,
      "damage_type" => "抓伤"
    }
  ]

  @impl true
  def id(), do: "qianzhu-wandushou"

  # LPC hit_ob：lvl>=80 且 jiali>=10 且 damage!=0，`jiali*2 + random(lvl)`
  # 压过对手 force 时上「蛛蛊毒」（duration = lvl/50 + random(lvl/20)）。
  # 注意 LPC 这里 affect_by 不在 `&&` 里（先上毒再无条件出文案），因 POISON
  # daemon 的 do_effect 对合法 para 恒返回 1，两种写法结果等价。
  @impl true
  def hit_ob(attacker, victim, damage, _factor, rng) do
    PoisonHit.strike(attacker, victim, damage, rng,
      skill: id(),
      cnd: "qianzhu_wandushou",
      msg: "$n忽然感到一股莫名的恶心，毒气攻心，全身顿时瘫软。\n"
    )
  end

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry"]

  # LPC valid_learn：`query("character")` 性格门（光明磊落 / 狡黠多变拒绝）+
  # 空手 / force>=150 / max_neili>=1000 / hand>=80 且 >=本技能。
  # 性格门属引擎未建模层（`meta.character` 恒 nil），未迁移；空手同理。

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  # LPC practice_skill 恒返回 notify_fail("千蛛万毒手只有通过吸取毒虫的毒素练功来提高。\n")
  # → `nil`（本引擎语义：只能用学(learn)的来增加熟练度）
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 qianzhu-wandushou.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)
    personality = personality_of(character)

    cond do
      personality == "光明磊落" ->
        {:error, "你心中暗想：我为人光明磊落，岂能学习这种害人武功？\n"}

      personality == "狡黠多变" ->
        {:error, "你心中暗想：哼，这种武功虽然厉害，但对自身损害极大，学来何用？\n"}

      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练千蛛万毒手必须空手。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候不够，无法练习千蛛万毒手。\n"}

      not is_nil(max_neili) and max_neili < 1000 ->
        {:error, "你的内力太弱，无法练习千蛛万毒手。\n"}

      Stats.skill(stats, "hand") < 80 ->
        {:error, "你的基本手法火候不够，无法练千蛛万毒手。\n"}

      Stats.skill(stats, "hand") < lvl ->
        {:error, "你的基本手法水平有限，无法领会更高深的千蛛万毒手。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "suck" => Kantele.Combat.Skills.Performs.QianzhuWandushou.Suck,
      "wan" => Kantele.Combat.Skills.Performs.QianzhuWandushou.Wan,
      "zhugu" => Kantele.Combat.Skills.Performs.QianzhuWandushou.Zhugu
    }
  end

  # LPC `me->query("character")`：天性。本端口未建模 register 流程 → 恒 nil，
  # 与 LPC 未设定时 `query()` 返回 0 等价（`nil == "X"` 假、`nil != "X"` 真）。
  defp personality_of(%{meta: meta}) when is_map(meta), do: Map.get(meta, :character)
  defp personality_of(_character), do: nil

end
