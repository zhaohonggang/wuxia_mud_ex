defmodule Kantele.Combat.Skills.YunvXinjing do
  @moduledoc """
  玉女心经（对照 `kungfu/skill/yunv-xinjing.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 素心诀/玄门内功/先天功/全真心法 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制与 `max_neili>=2000` 检查
    （`valid_learn/1` 仅有 stats，无 vitals）未实现。
  - `hit_ob` 被动（剑/鞭额外伤害）未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "yunv-xinjing"

  # LPC hit_ob（combatd.c:707 force 路径）：门控 lvl<150、neili<300、无武器、
  # random(force/6)<对手con、random(3)>1、未学成 wall(can_learn/yunv-xinjing/wall) → 不触发；
  # wall 未建模→按已学成。sword 分支须 mapped sword==suxin-jian；whip 分支须
  # mapped whip==yinsuo-jinling。各自给对手追加 receive_damage(qi,db_local)+
  # receive_wound(qi,db_local*2/3)，db_local = lvl/5(+random) 或 lvl/4(+random)。
  # 未建模：me->add("neili",-50) 自耗。
  @impl true
  def hit_ob(attacker, victim, _db, _factor, rng) do
    lvl = Map.get(attacker.skills, id(), 0)
    force = Map.get(attacker.skills, "force", 0)

    if lvl < 150 or attacker.neili < 300 or is_nil(attacker.weapon_name) or
         Kantele.Combat.Engine.rand(rng, max(div(force, 6), 1)) < victim.con or
         Kantele.Combat.Engine.rand(rng, 3) > 1 or
         Map.get(attacker.mapped, "force") != id() do
      {0, nil}
    else
      wst = attacker.weapon_skill_type

      case {wst, Map.get(attacker.mapped, "sword"), Map.get(attacker.mapped, "whip")} do
        {"sword", "suxin-jian", _} ->
          yunv_wound(attacker, lvl, div(lvl, 5), rng,
            "$N手中" <> attacker.weapon_name <>
              "忽的一振，将玉女心经功力运于剑端，漫出无边寒意。\n")

        {"whip", _, "yinsuo-jinling"} ->
          yunv_wound(attacker, lvl, div(lvl, 4), rng,
            "$N一声娇喝，将玉女心经功力运至" <> attacker.weapon_name <>
              "之上，姿势妙曼，令人肃然起敬。\n")

        _ ->
          {0, nil}
      end
    end
  end

  defp yunv_wound(attacker, _lvl, base, rng, msg) do
    db_local = base + Kantele.Combat.Engine.rand(rng, max(base, 1))
    extra = db_local + div(db_local * 2, 3)
    {max(extra, 0), msg, []}
  end

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force),
    do: force in ["suxin-jue", "xuanmen-neigong", "xiantian-gong", "quanzhen-xinfa"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 150 ->
        {:error, "你的基本内功火候还不够，不能修习玉女心经。\n"}

      stats.int < 32 ->
        {:error, "你的先天悟性不足，无法领悟玉女心经。\n"}

      true ->
        :ok
    end
  end

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"powerup" => Kantele.Combat.Skills.YunvXinjing.Powerup}
  end
end

defmodule Kantele.Combat.Skills.YunvXinjing.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/yunv-xinjing/powerup.c`）

  需 150 内力，耗 100；临时提升 attack=defense=玉女/3，持续 玉女 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "yunv-xinjing/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "yunv-xinjing"}, 3},
           defense: {:div, {:skill, "yunv-xinjing"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "yunv-xinjing"},
      expire_message: "你的玉女心经运行完毕，将内力收回丹田。\n",
      message: "$N脸色微微一沉，默运玉女心经，双掌向外一分，姿势曼妙之极。\n"
    }
end
