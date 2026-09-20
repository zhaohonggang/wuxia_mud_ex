defmodule Kantele.Combat.Skills.SankuShengong do
  @moduledoc """
  三苦神功（对照 `kungfu/skill/sanku-shengong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  LPC 未声明 `valid_force`，故恒真。

  差异（TODO(migrate)）：
  - `dispel`（排除异常）实现如下，可对自己/他人，清除所有 conditions。
  - `roar`（碧云神吼）实现如下，全房间攻击。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kalevala.Event

  @impl true
  def id(), do: "sanku-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(_force), do: true

  @impl true
  def valid_learn(_stats), do: :ok

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.SankuShengong.Powerup,
      "dispel" => Kantele.Combat.Skills.SankuShengong.Dispel,
      "roar" => Kantele.Combat.Skills.SankuShengong.Roar
    }
  end
end

defmodule Kantele.Combat.Skills.SankuShengong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/sanku-shengong/powerup.c`）

  取**基本 force** 等级：需 80 内力，耗 100；attack=defense=基本内功/3，
  持续 基本内功 秒；战斗中 busy 3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "sanku-shengong/powerup",
      gates: [
        {:neili_min, 80, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "force"}, 3},
           defense: {:div, {:skill, "force"}, 3}
         }}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "force"},
      expire_message: "你的三苦神功运行完毕，将内力收回丹田。\n",
      message: "$N凝神息气，运起三苦神功的最高境界，只见一股轻烟缭绕周身。\n"
    }
end

defmodule Kantele.Combat.Skills.SankuShengong.Dispel do
  @moduledoc """
  排除异常「dispel」（对照 `kungfu/skill/sanku-shengong/dispel.c`）

  门槛：neili>=100；扣 neili 100；清除自身所有 conditions；busy 1~2。

  差异：LPC 支持对他人施放（neili>=250、扣 250），当前 exert 命令不解析目标，
  仅实现自身分支（TODO(migrate)）。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "sanku-shengong/dispel",
      kind: :exert,
      gates: [
        {:neili_min, 100, "你的内力不足，无法运满一个周天。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:custom, &effect_dispel/2}
      ],
      busy: {:random, 1, 2},
      message: "$N深吸一口气，又缓缓的吐了出来。\n你默运三苦神功，开始排除身体中的异常症状。\n"
    }

  alias Kantele.Character.Combat
  alias Kantele.Character.Vitals

  defp effect_dispel(state, ctx) do
    # conditions 存 conn session（condition_event.ex 契约），从 session 清除
    conn = ctx.conn

    conn =
      if map_size(conn.session["conditions"] || %{}) > 0 do
        conn
        |> Kalevala.Character.Conn.put_session("conditions", nil)
        |> Kalevala.Character.Conn.put_session("cond_applyer", nil)
      else
        conn
      end

    state
    |> Map.put(:conn, conn)
    |> Map.update(:messages, [], fn msgs -> msgs ++ ["你调息完毕，将内力收回丹田。\n"] end)
  end
end

defmodule Kantele.Combat.Skills.SankuShengong.Roar do
  @moduledoc """
  碧云神吼「roar」（对照 `kungfu/skill/sanku-shengong/roar.c`）

  门槛：neili>=500、skill>=50、非 no_fight 房间。
  扣 neili 150，受损 qi 10，busy 1。
  全房间遍历：con 对抗失败者受 jing 伤害、可能昏迷。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform "sanku-shengong/roar"
  @name "「碧云神吼」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat
    vitals = character.meta.vitals

    with :ok <- gate_no_fight(ctx(character)),
         :ok <- gate_requirements(ctx(character)) do
      new_vitals = %{vitals | neili: max(vitals.neili - 150, 0), qi: max(vitals.qi - 10, 0)}
      character = %{character | meta: %{character.meta | vitals: new_vitals}}
      new_combat = Combat.start_busy(combat, 1)
      character = %{character | meta: %{character.meta | combat: new_combat}}

      skill = Stats.skill(stats, "force")
      message = "$N深深地吸一囗气，真力迸发，发出一声惊天动地的巨吼唐门无敌。\n"

      # 引擎未向 perform 暴露房间角色列表（conn.private 无 room_characters），
      # 全房间 AoE 退化为对战斗敌人发 perform-incoming（与 jie/dan 一致；
      # LPC 全房间广播差异记 TODO(migrate)）。
      room_chars = combat.enemies
      Enum.each(room_chars, fn target ->
        if not target.meta.combat.dead do
          send(target.pid, %Event{
            from_pid: self(),
            topic: "combat/perform-incoming",
            data: %{
              attacker: ref(character),
              perform_id: @perform,
              skill: skill,
              rng: &:rand.uniform/1
            }
          })
        end
      end)

      conn
      |> put_character(character)
      |> Broadcast.publish(message, n1: character.name)
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
    rng = Map.get(data, :rng, &:rand.uniform/1)
    skill = Map.get(data, :skill, 0)
    con = character.meta.stats.con || 20

    if div(skill, 2) + rng.(div(skill, 2)) < con * 2 do
      conn
    else
      max_neili = character.meta.vitals.max_neili
      damage = skill - div(max_neili, 10)

      if damage > 0 do
        new_jing = max(character.meta.vitals.jing - damage * 2, 0)
        new_max_jing = max(character.meta.vitals.max_jing - damage, 0)

        if character.meta.vitals.neili < skill * 2 do
          new_max_jing = max(new_max_jing - damage, 0)
        end

        new_character =
          %{character | meta: %{character.meta | vitals: %{character.meta.vitals | jing: new_jing, max_jing: new_max_jing}}}

        conn
        |> put_character(new_character)
        |> Broadcast.publish("你觉得眼前一阵金星乱冒，耳朵痛得像是要裂开一样。\n", n2: character.name)
      else
        conn
      end
    end
  end

  defp gate_no_fight(%{room: room}) do
    if not room.no_fight, do: :ok, else: {:error, "这里不能攻击别人! \n"}
  end

  defp gate_requirements(%{character: character}) do
    if character.meta.vitals.neili >= 500 && Stats.skill(character.meta.stats, "sanku-shengong") >= 50 do
      :ok
    else
      {:error, "你鼓足真气\"喵\"的吼了一声, 结果吓走了几只老鼠。\n"}
    end
  end

  defp ctx(character) do
    %{character: character, room: %{no_fight: false}}
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end

