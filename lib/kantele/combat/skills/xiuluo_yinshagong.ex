defmodule Kantele.Combat.Skills.XiuluoYinshagong do
  @moduledoc """
  修罗阴煞功（对照 `kungfu/skill/xiuluo-yinshagong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 五毒心法/蛤蟆功/瞬息千里 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的「无性」性别限制未实现（本模型暂无性别字段）。
  - `suck`（取毒液练药）依赖 LPC 的毒虫生物（`is_worm`/`query("worm_poison")`）
    宿主与 `clone/misc/chongdu` 虫毒药丸物品，两者本引擎均未建模，作为
    文档化降级：门槛实装，毒虫宿主需目标快照携带 `worm_poison` 才触发，
    药丸不入背包（仅文案）；见 Suck moduledoc。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "xiuluo-yinshagong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force in ["wudu-xinfa", "hamagong", "shunxi-qianli"]

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "force") < 60 do
      {:error, "你的基本内功火候还不够。\n"}
    else
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
      "powerup" => Kantele.Combat.Skills.XiuluoYinshagong.Powerup,
      "suck" => Kantele.Combat.Skills.XiuluoYinshagong.Suck
    }
  end
end

defmodule Kantele.Combat.Skills.XiuluoYinshagong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/xiuluo-yinshagong/powerup.c`）

  需 100 内力，耗 100；临时提升 attack=defense=修罗/3，持续 修罗 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "xiuluo-yinshagong/powerup",
      gates: [
        {:neili_min, 100, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "xiuluo-yinshagong"}, 3},
           defense: {:div, {:skill, "xiuluo-yinshagong"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "xiuluo-yinshagong"},
      expire_message: "你的修罗阴煞功运行完毕，将内力收回丹田。\n",
      message: "$N运起修罗阴煞功，头顶黑气蒸腾，全身肌肤坟起黑色的鳞甲，双目凶光四射！\n"
    }
end

defmodule Kantele.Combat.Skills.XiuluoYinshagong.Suck do
  @moduledoc """
  取毒液练药「suck」（对照 `kungfu/skill/xiuluo-yinshagong/suck.c`）

  需五毒奇术 >=100、修罗阴煞功 >=100、内力 >=200；耗内力 50、
  busy 1..3。对目标毒虫迫出毒液：`lvl = poison/3 + wudu/3 + xiuluo/3`，
  `amount = min(level*remain, lvl)`，扣减虫体 remain、目标上
  `poison-supply` 条件；amount 不足成丸时只挤出少量，够格则炼成一棵
  虫毒药丸并历练毒技。

  差异（TODO(migrate)）：
  - LPC 毒虫宿主（`is_worm` + `worm_poison`）与 `clone/misc/chongdu` 物品
    未建模：毒虫需目标快照（`enemies`）携带 `worm_poison` 方触发；虫毒药丸
    不生成物品实例，仅文案表达；`improve_skill` 技能历练未建模。
  - LPC 非毒虫/无毒液时以提示打回攻击方；本引擎改由攻击方预读快照前置拒绝，
    目标侧无 `worm_poison` 则直接放弃结算。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Performs

  @perform_id "xiuluo-yinshagong/suck"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- gate_wudu(stats),
         :ok <- gate_xiuluo(stats),
         :ok <- gate_neili(character),
         {:ok, target} <- find_target(combat) do
      conn =
        Broadcast.publish(
          conn,
          "$N伸出食指，点向$n腹部，默运内力迫出毒液练药。\n",
          n1: character.name,
          n2: target.name
        )

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          poison_lvl: Stats.skill(stats, "poison"),
          wudu_lvl: Stats.skill(stats, "wudu-qishu"),
          xiuluo_lvl: Stats.skill(stats, "xiuluo-yinshagong"),
          rng: &:rand.uniform/1
        }
      })

      vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 50, 0)}
      combat = Combat.start_busy(combat, :rand.uniform(3) - 1)
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
    poison_lvl = Map.get(data, :poison_lvl, 0)
    wudu_lvl = Map.get(data, :wudu_lvl, 0)
    xiuluo_lvl = Map.get(data, :xiuluo_lvl, 0)

    worm_poison = Map.get(character.meta, :worm_poison)

    if is_nil(worm_poison) or not is_map(worm_poison) do
      Performs.feedback(attacker, %{neili_cost: 0, busy: 0})
      conn
    else
      lvl = div(poison_lvl, 3) + div(wudu_lvl, 3) + div(xiuluo_lvl, 3)
      total = worm_poison.level * worm_poison.remain
      amount = min(total, lvl)
      remain = div(total - amount, worm_poison.level)

      meta = Map.put(character.meta, :worm_poison, %{worm_poison | remain: remain})

      conditions = Map.put(conn.session["conditions"] || %{}, "poison-supply", true)

      conn =
        conn
        |> Kalevala.Character.Conn.put_session("conditions", conditions)
        |> put_character(%{character | meta: meta})

      conn =
        if amount < 1 do
          Broadcast.publish(
            conn,
            "$N挤了半天，结果啥也没有挤出来，算是白忙活了。\n",
            n1: attacker.name,
            n2: character.name
          )
        else
          if amount < lvl do
            Broadcast.publish(
              conn,
              "$N挤了一点毒液出来，可惜这点毒液连炼一颗毒药都不够。\n",
              n1: attacker.name,
              n2: character.name
            )
          else
            Broadcast.publish(
              conn,
              "$N将$n的毒液逼出，在内力的作用下化成了一颗晶莹剔透的药丸。\n",
              n1: attacker.name,
              n2: character.name
            )
          end
        end

      Performs.feedback(attacker, %{neili_cost: 0, busy: 0})
      conn
    end
  end

  defp gate_wudu(stats) do
    if Stats.skill(stats, "wudu-qishu") >= 100 do
      :ok
    else
      {:error, "你的五毒奇术不够娴熟，不能炼制毒药。\n"}
    end
  end

  defp gate_xiuluo(stats) do
    if Stats.skill(stats, "xiuluo-yinshagong") >= 100 do
      :ok
    else
      {:error, "你修罗阴煞功修为不够，不能炼制毒药。\n"}
    end
  end

  defp gate_neili(character) do
    if character.meta.vitals.neili >= 200 do
      :ok
    else
      {:error, "你现在内力不足，难以炼制毒药。\n"}
    end
  end

  defp find_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "你要取哪只虫的毒液练药？\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end
