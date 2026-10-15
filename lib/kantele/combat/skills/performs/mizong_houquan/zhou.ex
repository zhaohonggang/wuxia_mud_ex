defmodule Kantele.Combat.Skills.Performs.MizongHouquan.Zhou do
  @moduledoc """
  破釜沉舟「zhou」（对照 `kungfu/skill/mizong-houquan/zhou.c`）

  迷踪猴拳连招：需空手（无兵器/副兵器）、猴拳>=200、真气>=500。连出
  `n = 2 + random(猴拳/40)`（上限 8；若已预备 unarmed/strike 绝招则减 3）招，
  每招随机取一句口诀并以 `COMBAT_D->do_attack` 结算；每招扣 50 真气，
  收招忙乱 `random(n)`。

  差异（TODO(migrate)）：
  - LPC 无 can_perform 门槛，保留 perform_known 守卫（多 1 条信息性 EXTRA）；
  - `COMBAT_D->do_attack` 无自定义文案，折算为逐招命中判定 + 伤害；
  - `add_temp("apply/attack"|"apply/unarmed_damage")` 的逐招临时增益折算进
    各招的 ap / 伤害；
  - `chinese_number` 折算为十进制字符串（同 `Kantele.World.Room`）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "mizong-houquan/zhou"

  # LPC: string *msgs = ({ ... });
  @msgs [
    "笑问七剑一指仙！",
    "叶落枫舞二穿山！",
    "袖里风云三点头！",
    "回首太白四气刀！",
    "化月孤心五看地！",
    "茫茫秋水六荒天！",
    "笑问叶落看风云！",
    "回首化月望秋水！"
  ]

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat
    rng = &:rand.uniform/1

    with :ok <- check_perform_known(stats),
         :ok <- check_busy(combat),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_unarmed(combat),
         {:ok, target} <- check_target(combat),
         :ok <- check_neili(character) do
      apply_perform(conn, character, target, level, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (me->is_busy()) return notify_fail("你现在没空！！\n");
  defp check_busy(combat) do
    if combat.busy > 0 do
      {:error, "你现在没空！！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("mizong-houquan", 1) < 200)
  defp check_skill_level(stats) do
    level = Stats.skill(stats, "mizong-houquan")

    if level < 200 do
      {:error, "你的猴拳不够娴熟!\n"}
    else
      {:ok, level}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_unarmed(combat) do
    if Combat.weapon(combat) || Map.get(combat.equipped, :secondary_weapon) do
      {:error, "「破釜沉舟」只能空手使用。\n"}
    else
      :ok
    end
  end

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "［破釜沉舟］只能对战斗中的对手使用。\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你现在内力太弱，不能使用「破釜沉舟」。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, level, rng) do
    stats = character.meta.stats

    # LPC: n = 2 + random(me->query_skill("mizong-houquan", 1) / 40); if (n > 8) n = 8;
    n = min(2 + Engine.rand(rng, max(div(level, 40), 1)), 8)

    # LPC: if (me->query_skill_prepared("unarmed") || me->query_skill_prepared("strike")) n -= 3;
    n =
      if Stats.prepared?(stats, "unarmed") or Stats.prepared?(stats, "strike"),
        do: n - 3,
        else: n

    conn =
      Broadcast.publish(
        conn,
        "$N使出独步天下的［迷踪猴拳］，一招[破釜沉舟]打出了第一式！\n",
        n1: character.name,
        n2: target.name
      )

    strikes = max(n - 1, 0)

    # LPC: for (i = 1; i < n; i++) { msg = msgs[random(sizeof(msgs))];
    #          msg = HIC "\n第" + chinese_number(i) + "招---" + msg + NOR; message_vision(...); }
    conn =
      if strikes > 0 do
        Enum.reduce(1..strikes, conn, fn i, conn ->
          chosen = Enum.at(@msgs, Engine.rand(rng, length(@msgs)))

          Broadcast.publish(
            conn,
            "\n第" <> chinese_number(i) <> "招---" <> chosen <> "\n",
            n1: character.name,
            n2: target.name
          )
        end)
      else
        conn
      end

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: level,
        strikes: strikes,
        n: n,
        rng: rng
      }
    })

    conn
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    # .c 无 living(target) 门槛；目标已死时静默（同 biyan_dao/luo.ex）。
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    level = max(Map.get(data, :level, 0), 1)
    strikes = Map.get(data, :strikes, 0)
    n = Map.get(data, :n, 1)
    dodge = Stats.skill(character.meta.stats, "dodge")

    # LPC 逐招 COMBAT_D->do_attack(me, target)，每招 add_temp apply/attack = i*50、
    # apply/unarmed_damage = i*10；折算为逐招 ap = level + i*50 的命中判定与伤害。
    damage =
      if strikes > 0 do
        Enum.reduce(1..strikes, 0, fn i, acc ->
          ap = level + i * 50

          if div(ap, 2) + Engine.rand(rng, ap) > dodge do
            acc + level + i * 10 + Engine.rand(rng, level)
          else
            acc
          end
        end)
      else
        0
      end

    vitals =
      if damage > 0 do
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage, 3))
      else
        character.meta.vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: 每招 me->add("neili", -50)；me->start_busy(random(i))（i == n）
    Performs.feedback(attacker, 50 * max(strikes, 0), Engine.rand(rng, max(n, 1)))

    put_character(conn, character)
  end

  defp chinese_number(n), do: Integer.to_string(n)

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "mizong-houquan/zhou",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
