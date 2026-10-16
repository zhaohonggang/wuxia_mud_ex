defmodule Kantele.Combat.Skills.Performs.FireiceStrike.Binghuo do
  @moduledoc """
  冰火二重天「binghuo」（对照 `kungfu/skill/fireice-strike/binghuo.c`）

  烈焰寒冰掌攻击绝招：须空手、fireice-strike>=150、yunv-xinjing>=120、
  strike 已激发映射 fireice-strike、max_neili>=800、neili>=800。
  对持有九阳神功映射的目标走「九阳」分支（按 force 判定，仅扣内力/忙乱）；
  否则按 parry 判定，命中则算伤，且 fireice-strike>150 时施展第二掌（perform2）。
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

  @perform_id "fireice-strike/binghuo"
  @move_name "「冰火二重天」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_yunv(stats),
         :ok <- check_mapped(stats),
         :ok <- check_max_neili(character),
         :ok <- check_neili(character) do
      apply_perform(conn, character, target, stats)
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

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中使用。\n"}
    end
  end

  defp check_weapon(combat) do
    if Combat.weapon(combat) == nil do
      :ok
    else
      {:error, "只有空手才能施展#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "fireice-strike") < 150 do
      {:error, "你的烈焰寒冰掌功夫还不够娴熟，不会使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_yunv(stats) do
    if Stats.skill(stats, "yunv-xinjing") < 120 do
      {:error, "以你现在的玉女心经还使不出#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "strike") == "fireice-strike" do
      :ok
    else
      {:error, "你现在无法使用#{@move_name}进行攻击。\n"}
    end
  end

  defp check_max_neili(character) do
    if Map.get(character.meta.vitals, :max_neili, 0) < 800 do
      {:error, "你的内力修为太弱，不能使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 800 do
      {:error, "你的真气不够！\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, stats) do
    jiuyang? = Stats.mapped(target.meta.stats, "force") == "jiuyang-shengong"

    start_msg =
      if jiuyang? do
        # LPC: HIR"$N" HIR"左手手心隐隐透红光，一股炽热掌气向" HIR"$n" HIR"迎脸扑来！\n" NOR
        "$N左手手心隐隐透红光，一股炽热掌气向$n迎脸扑来！\n"
      else
        # LPC: HIR "\n$N" HIR "左手手心隐隐透红光，一股炽热掌气直袭" HIR "$n" HIR "胸口！\n"NOR
        "$N左手手心隐隐透红光，一股炽热掌气直袭$n胸口！\n"
      end

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        fireice: Stats.skill(stats, "fireice-strike"),
        force: Stats.skill(stats, "force"),
        parry: Stats.skill(stats, "parry"),
        dodge: Stats.skill(stats, "dodge"),
        neili: character.meta.vitals.neili,
        jiuyang?: jiuyang?,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> Broadcast.publish(start_msg, n1: character.name, n2: target.name)
    |> assign(:prompt, false)
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    cond do
      character.meta.combat.dead -> conn
      Map.get(data, :jiuyang?, false) -> resolve_jiuyang(conn, character, attacker, data)
      true -> resolve_normal(conn, character, attacker, data)
    end
  end

  defp resolve_jiuyang(conn, character, attacker, data) do
    force = max(Map.get(data, :force, 0), 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    dp = div(Stats.skill(character.meta.stats, "force"), 4)
    bindings = [n1: attacker.name, n2: character.name]

    if Engine.rand(rng, max(force, 1)) > dp do
      # LPC: me->add("neili", -100); msg += HIY "$n一见之下，暗运九阳神功作出抵抗！！..."
      Performs.feedback(attacker, 100, 0)

      Broadcast.publish(conn, "$n一见之下，暗运九阳神功作出抵抗！！脸色转了几转，安然无恙！\n", bindings)
    else
      # LPC: me->start_busy(3); me->add("neili", -200); msg += HIW"$p" HIW"大喝一声..."
      Performs.feedback(attacker, 200, 3)

      Broadcast.publish(
        conn,
        "$p大喝一声“来的正好！”猛运九阳真气，\n$N的掌力竟被反震，血气翻腾！连退数步！\n",
        bindings
      )
    end
  end

  defp resolve_normal(conn, character, attacker, data) do
    parry = max(Map.get(data, :parry, 0), 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    dp = div(Stats.skill(character.meta.stats, "parry"), 3)
    bindings = [n1: attacker.name, n2: character.name]

    if Engine.rand(rng, max(parry, 1)) > dp do
      # LPC: me->start_busy(1); target->start_busy(1); me->add("neili", -300);
      #      damage = random(fireice-strike) + 300; do_damage(..., 40, ...)
      fireice = max(Map.get(data, :fireice, 0), 0)
      damage = Engine.rand(rng, max(fireice, 1)) + 300
      vitals = Vitals.wound(character.meta.vitals, :qi, div(damage * 40, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}
      combat = Combat.start_busy(character.meta.combat, 1)
      character = %{character | meta: %{character.meta | combat: combat}}

      conn = Broadcast.publish(conn, "$n顿时觉得胸口如被火烧，一口真气难以继回!!\n", bindings)

      Performs.feedback(attacker, 300, 1)

      conn = put_character(conn, character)

      if fireice > 150 do
        resolve_second_palm(conn, character, attacker, data)
      else
        conn
      end
    else
      # LPC: me->start_busy(3); me->add("neili", -100); msg += HIW"可是$p一个巧云翻身..."
      Performs.feedback(attacker, 100, 3)

      Broadcast.publish(conn, "可是$p一个巧云翻身，远远的躲了开去。\n", bindings)
    end
  end

  # LPC perform2（call_out）：第二掌结算，文案并入同一 resolve 流程。
  defp resolve_second_palm(conn, character, attacker, data) do
    bindings = [n1: attacker.name, n2: character.name]

    if character.meta.combat.dead do
      Broadcast.publish(conn, "对手已经不能再战斗了。\n", bindings)
    else
      if Map.get(data, :neili, 0) < 600 do
        # LPC: return notify_fail("你待要再出第二掌，却发现自己的内力不够了！\n")
        Broadcast.publish(conn, "你待要再出第二掌，却发现自己的内力不够了！\n", bindings)
      else
        # LPC: msg = HIB "\n接着" HIB "$N" HIB "挥出右手，手心竟是暗隐寒劲，以巧妙角度向" HIB "$n" HIB "拍过去!\n"NOR
        conn = Broadcast.publish(conn, "\n接着$N挥出右手，手心竟是暗隐寒劲，以巧妙角度向$n拍过去!\n", bindings)

        fireice = max(Map.get(data, :fireice, 0), 0)
        rng = Map.get(data, :rng, &:rand.uniform/1)
        dodge = max(Map.get(data, :dodge, 0), 0)
        target_dodge = Stats.skill(character.meta.stats, "dodge")

        if Engine.rand(rng, max(dodge, 1)) > div(target_dodge, 2) do
          # LPC: me->start_busy(1); me->add("neili", -300); do_damage(..., 60, ...)
          damage = Engine.rand(rng, max(fireice, 1)) + 300
          vitals = Vitals.wound(character.meta.vitals, :qi, div(damage * 60, 100))
          character = %{character | meta: %{character.meta | vitals: vitals}}

          conn = Broadcast.publish(conn, "结果一掌击中，$n只觉得全身气脉通道如遭冻结，脸色一下变白！\n", bindings)

          Performs.feedback(attacker, 300, 1)

          put_character(conn, character)
        else
          # LPC: me->start_busy(3); me->add("neili", -100);
          #      msg += HIY "\n$p" HIY "眼看寒气逼人，暗生警觉，顺势跳了开去。\n" NOR
          conn = Broadcast.publish(conn, "$p眼看寒气逼人，暗生警觉，顺势跳了开去。\n", bindings)

          Performs.feedback(attacker, 100, 3)

          conn
        end
      end
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "fireice-strike/binghuo",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
