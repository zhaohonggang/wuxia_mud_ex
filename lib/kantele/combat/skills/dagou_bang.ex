defmodule Kantele.Combat.Skills.DagouBang do
  @moduledoc """
  打狗棒法（对照 `kungfu/skill/dagou-bang.c`）

  棒法载体：`valid_enable("staff")` / `valid_enable("parry")`。

  招式表取 LPC `action` 表的 4 式静态招式（LPC 未为前 4 式标注 lvl/skill_name，
  视作 lvl 0），第 5 式「极意」（lvl 200）的力/攻/闪/架/伤由 `query_action/3`
  按出招者的 `force`/`staff`/`dodge`/`parry` **实时生成**（见 `@ultimate` 与
  `ultimate_values/2`）。

  注意：LPC `query_action` 为 `action[random(sizeof(action))]`，不按等级过滤；
  本引擎统一用 `pick_action/3`（`level > lvl` 严格过滤 + NewRandom 加权），
  且「极意」仅在 level > 200 时并入，与 `huashan-jian` 等绝学保持一致。

  绝招实现见 `lib/kantele/combat/skills/performs/dagou_bang/`。

  **未迁移**：`valid_learn` 门槛（LPC dex>=26, max_neili>=1500, staff>=100 且
  staff>=dagou-bang）—— 见 TODO(migrate)。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  # 第 5 式「极意」的静态部分；五项数值由 ultimate_values/2 出招时生成
  @ultimate %{
    "action" => "$N凝神静气，使出极招 打狗棒法之极意 ",
    "lvl" => 200,
    "skill_name" => "极意",
    "damage_type" => "挫伤"
  }

  @actions [
    %{
      "action" => "$N使出一招「棒打双犬」，手中$w化作两道青光砸向$n的$l",
      "force" => 280,
      "attack" => 98,
      "parry" => 100,
      "dodge" => 120,
      "damage" => 80,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N手中$w左右晃动，一招「拨草寻蛇」向$n的$l攻去",
      "force" => 300,
      "attack" => 100,
      "parry" => 120,
      "dodge" => 100,
      "damage" => 100,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N举起$w，居高临下使一招「打草惊蛇」敲向$n的$l",
      "force" => 290,
      "attack" => 99,
      "parry" => 100,
      "dodge" => 120,
      "damage" => 70,
      "damage_type" => "挫伤"
    },
    %{
      "action" => "$N施出「拨狗朝天」，$w由下往上向$n撩去",
      "force" => 310,
      "attack" => 105,
      "parry" => 140,
      "dodge" => 80,
      "damage" => 90,
      "damage_type" => "挫伤"
    }
  ]

  @impl true
  def id(), do: "dagou-bang"

  @impl true
  def valid_enable(usage), do: usage in ["staff", "parry"]

  # LPC valid_learn 要求 dex>=26, max_neili>=1500, staff>=100 且 staff>=dagou-bang，
  # 引擎暂未建模。
  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练"
  @impl true
  def practice_cost(), do: nil

  @doc "按等级加权随机选一式（招式表 + NewRandom；前 4 式 lvl 0，level>=1 均可选）"
  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @doc """
  带角色上下文选招：等级 > 200 时把动态第 5 式「极意」并入招式表

  LPC 原文（`kungfu/skill/dagou-bang.c`）：

      "force"  : query_skill("force",1)/2 + random(query_skill("force",1)),
      "attack" : query_skill("staff",1)/4 + random(query_skill("staff",1)/2),
      "dodge"  : query_skill("dodge",1)/4 + random(query_skill("force",1)/3),
      "parry"  : query_skill("parry",1)/4 + random(query_skill("parry",1)/3),
      "damage" : query_skill("force",1)/3 + random(query_skill("staff",1)/3)
  """
  @impl true
  def query_action(level, rng, attacker) do
    Skill.pick_action_with_ultimate(
      @actions,
      level,
      attacker,
      @ultimate,
      &ultimate_values/2,
      rng
    )
  end

  defp ultimate_values(attacker, rng) do
    force = Skill.skill_of(attacker, "force")
    staff = Skill.skill_of(attacker, "staff")
    dodge = Skill.skill_of(attacker, "dodge")
    parry = Skill.skill_of(attacker, "parry")
    r = &Skill.lpc_random(rng, &1)

    %{
      "force" => div(force, 2) + r.(force),
      "attack" => div(staff, 4) + r.(div(staff, 2)),
      "dodge" => div(dodge, 4) + r.(div(force, 3)),
      "parry" => div(parry, 4) + r.(div(parry, 3)),
      "damage" => div(force, 3) + r.(div(staff, 3))
    }
  end

  @impl true
  def perform_list() do
    %{
      "chan" => Kantele.Combat.Skills.Performs.DagouBang.Chan,
      "feng" => Kantele.Combat.Skills.Performs.DagouBang.Feng,
      "tian" => Kantele.Combat.Skills.Performs.DagouBang.Tian,
      "ban" => Kantele.Combat.Skills.Performs.DagouBang.Ban,
      "chuo" => Kantele.Combat.Skills.Performs.DagouBang.Chuo
    }
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @doc "第 5 式「极意」的静态部分（动态数值需角色上下文，见 `query_action/3`）"
  def ultimate(), do: @ultimate

  @doc "当前等级对应的最高招式名（query_skill_name，含极意）"
  def query_skill_name(level) do
    (@actions ++ [@ultimate])
    |> Enum.reverse()
    |> Enum.find(fn action -> level >= Map.get(action, "lvl", 0) end)
    |> case do
      nil -> nil
      action -> action["skill_name"]
    end
  end
end
