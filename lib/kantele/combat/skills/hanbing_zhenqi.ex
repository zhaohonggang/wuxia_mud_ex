defmodule Kantele.Combat.Skills.HanbingZhenqi do
  @moduledoc """
  寒冰真气（对照 `kungfu/skill/hanbing-zhenqi.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 华山心法/衡山心法/嵩山心法/紫霞神功/镇岳诀 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性格/性别/`max_neili` 检查未实现（注：性别/性格本模型已建模，
    见 MEMORY；此处 LPC 源码里性格门被注释掉，性别门亦注释，仅保留 force/max_neili 门，
    已迁移）。
  - `freezing`（寒冰真气）实现如下，需先 powerup、con>=34、skill>=140、max_neili>=2200、neili>=1000。
  - `hit_ob` 冰封被动 → 已迁移（combatd.c:707 攻击方内功钩子，经 `Engine.apply_force_hit_ob`
    触发，门控 neili>=500/lvl>=220/jiali>=100/random(2)/已运 freezing，上 `freezing` 寒毒；
    LPC `me->add("neili", -80)` 攻击者内力消耗因无跨进程通道未迁移）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.Engine

  @impl true
  def id(), do: "hanbing-zhenqi"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force),
    do:
      force in [
        "huashan-xinfa",
        "henshan-xinfa",
        "songshan-xinfa",
        "zixia-shengong",
        "zhenyue-jue"
      ]

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  # LPC `valid_learn(object me)`（源 hanbing-zhenqi.c）
  @impl true
  def valid_learn(stats), do: valid_learn(stats, nil)

  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)
    personality = personality_of(character)

    cond do
      personality == "光明磊落" ->
        {:error, "你心中暗想：我行事光明磊落，学这阴毒的武功做甚。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的基本内功火候不够，难以锻炼寒冰真气。\n"}

      not is_nil(max_neili) and max_neili < 1000 ->
        {:error, "你目前的内力修为不够，难以锻炼寒冰真气。\n"}

      Stats.skill(stats, "force") < lvl ->
        {:error, "你的基本内功水平不够，难以锻炼更深厚的寒冰真气。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  # LPC `hit_ob`（combatd.c:707，攻击方内功）：先 `::hit_ob` 得 force bonus（本引擎
  # 已并入 damage），`result>0` 等价门为 `damage>0`。门控对齐 LPC：neili>=500、
  # lvl>=220、jiali>=100、`random(2)==1`、且须先运「寒冰真气」(query_temp("freezing"))；
  # 满足 `jiali*2 + random(lvl) > 对手 force` 时给 victim 上 `freezing` 寒毒。
  # 注：LPC `me->add("neili", -80)` 是攻击方内力消耗，需跨进程攻击者 neili 通道，
  # 当前 `hit_ob/5` 契约无此返回位，本次未迁移（已知偏差，待补攻击者资源扣减通道）。
  @impl true
  def hit_ob(attacker, victim, damage, _factor, rng) do
    lvl = Stats.skill(attacker, id())
    flvl = attacker.jiali

    cond do
      damage <= 0 ->
        {0, nil}

      attacker.neili < 500 or lvl < 220 or flvl < 100 ->
        {0, nil}

      Engine.rand(rng, 2) != 1 ->
        {0, nil}

      not Map.get(attacker, :freezing_buff, false) ->
        {0, nil}

      flvl * 2 + Engine.rand(rng, lvl) > Map.get(victim.skills, "force", 0) ->
        {0,
         freezing_msg(attacker, rng),
         [
           {"freezing",
            %{
              "level" => flvl * 3,
              "id" => attacker.id,
              "duration" => div(lvl, 50) + Engine.rand(rng, div(lvl, 20))
            }}
         ]}

      true ->
        {0, nil}
    end
  end

  # LPC `random(2) ? A : B`：random(2) 返回 0/1，非 0（即 1）走 A。
  defp freezing_msg(attacker, rng) do
    if Engine.rand(rng, 2) == 1 do
      "$n接下$N一招，霎时只感到寒风袭体，说不出的恶心难受。\n"
    else
      "只见$n全身一颤，嘴皮乌紫，竟似受了$N寒冰内劲的干扰。\n"
    end
  end

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.HanbingZhenqi.Powerup,
      "freezing" => Kantele.Combat.Skills.HanbingZhenqi.Freezing
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  # LPC `me->query("character")`：天性。本端口未建模 register 流程 → 恒 nil，
  # 与 LPC 未设定时 `query()` 返回 0 等价（`nil == "X"` 假、`nil != "X"` 真）。
  defp personality_of(%{meta: meta}) when is_map(meta), do: Map.get(meta, :character)
  defp personality_of(_character), do: nil

end

defmodule Kantele.Combat.Skills.HanbingZhenqi.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/hanbing-zhenqi/powerup.c`）

  需 150 内力，耗 100；临时提升 attack=defense=寒冰/3，持续 寒冰 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "hanbing-zhenqi/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "hanbing-zhenqi"}, 3},
           defense: {:div, {:skill, "hanbing-zhenqi"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "hanbing-zhenqi"},
      expire_message: "你的寒冰真气运行完毕，将内力收回丹田。\n",
      message: "$N微一凝神，默默运转体内所蓄的寒冰真气，霎时面部竟呈出一层薄霜。\n"
    }
end

defmodule Kantele.Combat.Skills.HanbingZhenqi.Freezing do
  @moduledoc """
  寒冰真气「freezing」（对照 `kungfu/skill/hanbing-zhenqi/freezing.c`）

  门槛：寒冰>=140、con>=34、max_neili>=2200、neili>=1000、
  需先 powerup 状态、非 freezing 状态。
  扣 neili 300，设 temp freezing，busy 3。
  """

  use Kantele.Combat.Performs.Simple, spec: :local

  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Performs.Spec

  @impl true
  def spec do
    %Spec{
      id: "hanbing-zhenqi/freezing",
      kind: :exert,
      gates: [
        {:skill_min, "hanbing-zhenqi", 140, "你的寒冰真气不够，难以施展「寒冰真气」。\n"},
        {:custom, &gate_con/1, "你的先天根骨不足，无法施展「寒冰真气」。\n"},
        {:max_neili_min, 2200, "你的内力修为不足，难以施展「寒冰真气」。\n"},
        {:custom, &gate_powerup/1, "你现在尚未曾运功，难以施展「寒冰真气」。\n"},
        {:neili_min, 1000, "你目前的内力不够，难以施展「寒冰真气」。\n"},
        {:no_buff, "freezing", "你现在正在施展「寒冰真气」。\n"}
      ],
      costs: %{neili: 300},
      effects: [
        {:custom, &effect_freezing/1}
      ],
      busy: 3,
      duration: {:skill, "hanbing-zhenqi"},
      expire_message: "你的「寒冰真气」运行完毕，将内力收回丹田。\n",
      message: "$N一声冷笑，体内寒冰真气迅速疾转数个周天，将力聚于掌心。\n"
    }
  end

  defp gate_con(ctx),
    do: ctx.character.meta.stats.con >= 34

  defp gate_powerup(ctx),
    do: ctx.character.meta.combat.buffs |> Enum.any?(&(&1.key == "powerup"))

  defp effect_freezing(state) do
    char = state.character

    new_combat =
      char.meta.combat
      |> Combat.add_buff(%Kantele.Character.Combat.Buff{
        key: "freezing",
        applies: %{},
        duration: Stats.skill(char.meta.stats, "hanbing-zhenqi")
      })

    new_char = %{char | meta: %{char.meta | combat: new_combat}}
    %{state | character: new_char}
  end
end
