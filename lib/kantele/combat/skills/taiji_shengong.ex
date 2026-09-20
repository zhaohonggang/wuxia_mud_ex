defmodule Kantele.Combat.Skills.TaijiShengong do
  @moduledoc """
  太极神功（对照 `kungfu/skill/taiji-shengong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 混元一气功/易筋经/武当心法/临济庄/峨眉心法/少林心法 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制未实现（本模型暂无性别字段）。
  - `query_neili_improve` 成长公式未接入。
  - `dian`（鹤嘴劲点龙跃窍）需非战斗且有明确目标；引擎 `exert` 无目标参数、
    目标取自敌人列表，故成功路径与 `force/lifeheal` 同理暂不可达，目标侧结算可测。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "taiji-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force),
    do:
      force in [
        "hunyuan-yiqi",
        "yijinjing",
        "wudang-xinfa",
        "linji-zhuang",
        "emei-xinfa",
        "shaolin-xinfa"
      ]

  @impl true
  def valid_learn(stats) do
    force = Stats.skill(stats, "force")
    taoism = Stats.skill(stats, "taoism")
    level = Stats.skill(stats, id())

    cond do
      force < 100 ->
        {:error, "你的基本内功火候还不够。\n"}

      taoism < 100 ->
        {:error, "你对道家心法领悟的太浅，无法理解太极神功。\n"}

      taoism < 320 and taoism < level ->
        {:error, "你对道学心法的理解不够，难以锻炼更深厚的太极神功。\n"}

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
    %{
      "powerup" => Kantele.Combat.Skills.TaijiShengong.Powerup,
      "shield" => Kantele.Combat.Skills.TaijiShengong.Shield,
      "dian" => Kantele.Combat.Skills.TaijiShengong.Dian
    }
  end
end

defmodule Kantele.Combat.Skills.TaijiShengong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/taiji-shengong/powerup.c`）

  需 150 内力方可发动，实际耗 100；临时提升 attack=defense=太极/3，
  持续 太极 秒；战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "taiji-shengong/powerup",
      gates: [
        {:neili_min, 150, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "taiji-shengong"}, 3},
           defense: {:div, {:skill, "taiji-shengong"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "taiji-shengong"},
      expire_message: "你的太极神功运行完毕，将内力收回丹田。\n",
      message: "$N微一凝神，运起太极神功，全身灌满真气，衣裳无风自舞，气势迫人。\n"
    }
end

defmodule Kantele.Combat.Skills.TaijiShengong.Shield do
  @moduledoc """
  运功「shield」（对照 `kungfu/skill/taiji-shengong/shield.c`）

  需太极 ≥50，耗 100 内力，临时提升 armor=太极/2，持续 太极 秒；
  战斗中 busy 2 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "taiji-shengong/shield",
      gates: [
        {:neili_min, 100, "你的内力不够。\n"},
        {:skill_min, "taiji-shengong", 50, "你的太极神功修为不够。\n"},
        {:no_buff, "shield", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "shield", %{armor: {:div, {:skill, "taiji-shengong"}, 2}}}
      ],
      busy: {:if_fighting, 2},
      duration: {:skill, "taiji-shengong"},
      expire_message: "你的太极神功运行完毕，将内力收回丹田。\n",
      message: "$N深深吸了一口气，缓缓吐出，一股白烟冉冉透体而出，盘旋笼罩了全身。\n"
    }
end

defmodule Kantele.Combat.Skills.TaijiShengong.Dian do
  @moduledoc """
  鹤嘴劲点龙跃窍「dian」（对照 `kungfu/skill/taiji-shengong/dian.c`）

  运功为他人疗伤：需非战斗、太极神功 >=100、max_neili >=1500、
  内力 >=1000、jing >=100。耗内力 800、受 qi 伤 100、jing 伤 50、
  自身 busy 10；目标回复 qi=`100+force+taiji*3`、
  jing=`100+force/3+taiji`（上限 base 值）、目标 busy 2。

  差异（TODO(migrate)）：
  - 引擎 `exert` 无目标参数（目标取自敌人列表），而本招禁止战斗中使用，
    故攻击方成功路径不可达（同 `force/lifheal`，见 moduledoc）；目标侧
    `resolve_incoming` 可直接经 perform-incoming 触发并可测。
  - LPC 目标无伤（eff 全满）时以 notify_fail 打回攻击方，本引擎在目标侧
    `resolve_incoming` 判定无伤则放弃结算；复活（revive）未建模。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Performs

  @perform_id "taiji-shengong/dian"
  @dian "「鹤嘴劲点龙跃窍」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat
    vitals = character.meta.vitals

    with :ok <- gate_perform_known(stats),
         :ok <- gate_not_fighting(combat),
         :ok <- gate_skill_level(stats),
         :ok <- gate_max_neili(vitals),
         :ok <- gate_neili(vitals),
         :ok <- gate_jing(vitals),
         {:ok, target} <- find_target(combat) do
      conn =
        Broadcast.publish(
          conn,
          "$N双手食指和拇指虚拿，成鹤嘴劲势，以食指指尖点在$n耳尖三分处的龙跃窍，运起内功，微微摆动。\n",
          n1: character.name,
          n2: target.name
        )

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          force_lvl: Stats.skill(stats, "force"),
          taiji_lvl: Stats.skill(stats, "taiji-shengong"),
          rng: &:rand.uniform/1
        }
      })

      vitals =
        vitals
        |> Map.put(:neili, max(vitals.neili - 800, 0))
        |> Vitals.damage(:qi, 100)
        |> Vitals.damage(:jing, 50)

      combat = Combat.start_busy(combat, 10)
      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      conn
      |> put_character(character)
      |> assign(:prompt, false)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    force_lvl = Map.get(data, :force_lvl, 0)
    taiji_lvl = Map.get(data, :taiji_lvl, 0)

    cond do
      character.meta.combat.busy > 0 ->
        conn

      not needs_heal?(character.meta.vitals) ->
        conn

      true ->
        cure_qi = 100 + force_lvl + taiji_lvl * 3
        cure_jing = 100 + div(force_lvl, 3) + taiji_lvl

        t_vitals = character.meta.vitals

        t_vitals =
          t_vitals
          |> Vitals.curing(:qi, cure_qi)
          |> Vitals.curing(:jing, cure_jing)
          |> ensure_min()

        combat = Combat.start_busy(character.meta.combat, 2)
        character = %{character | meta: %{character.meta | vitals: t_vitals, combat: combat}}

        conn =
          conn
          |> Broadcast.publish(
            "过得一会便见得$n额头上冒出豆大汗珠，头上冒出隐隐白雾，哇的一下吐出瘀血，脸色登时看起来红润多了。\n",
            n1: attacker.name,
            n2: character.name
          )
          |> put_character(character)

        Performs.feedback(attacker, %{neili_cost: 0, busy: 0})
        conn
    end
  end

  defp needs_heal?(vitals) do
    vitals.max_qi < vitals.base_qi or vitals.max_jing < vitals.base_jing
  end

  defp ensure_min(%Vitals{qi: qi, max_qi: max_qi, jing: jing, max_jing: max_jing} = vitals) do
    vitals
    |> Map.put(:qi, max(qi, 1))
    |> Map.put(:max_qi, max(max_qi, 1))
    |> Map.put(:jing, max(jing, 1))
    |> Map.put(:max_jing, max(max_jing, 1))
  end

  defp gate_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所学的内功中没有这种功能。\n"}
    end
  end

  defp gate_not_fighting(combat) do
    if Combat.fighting?(combat) do
      {:error, "战斗中无法运功疗伤。\n"}
    else
      :ok
    end
  end

  defp gate_skill_level(stats) do
    if Stats.skill(stats, "taiji-shengong") >= 100 do
      :ok
    else
      {:error, "你的太极神功不够娴熟，难以施展" <> @dian <> "。\n"}
    end
  end

  defp gate_max_neili(vitals) do
    if vitals.max_neili >= 1500 do
      :ok
    else
      {:error, "你的内力修为太浅，难以施展" <> @dian <> "。\n"}
    end
  end

  defp gate_neili(vitals) do
    if vitals.neili >= 1000 do
      :ok
    else
      {:error, "你现在的真气不足，难以施展" <> @dian <> "。\n"}
    end
  end

  defp gate_jing(vitals) do
    if vitals.jing >= 100 do
      :ok
    else
      {:error, "你现在精神状态不佳，难以施展" <> @dian <> "。\n"}
    end
  end

  defp find_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "你要用真气为谁疗伤？\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end
