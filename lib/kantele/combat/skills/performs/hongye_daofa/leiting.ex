defmodule Kantele.Combat.Skills.Performs.HongyeDaofa.Leiting do
  @moduledoc """
  雷霆霹雳「leiting」（对照 `kungfu/skill/hongye-daofa/leiting.c`，inherit F_SSERVER）

  红叶刀法攻击绝招：要求不忙乱、hongye-daofa >= 80、持 blade 类武器、
  真气 >= 500、目标在战斗中。攻击方广播起手式并发 `combat/perform-incoming`，
  目标侧 `random(10) > 4` 时命中文案（伤害 `skill + rand(dodge)/2`，30% 外伤，
  扣 50 内力），否则“不退反进”文案（不扣内力）；两种分支均忙乱 1。
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

  @perform_id "hongye-daofa/leiting"
  @move_name "「雷霆霹雳」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         :ok <- check_busy(combat),
         {:ok, target} <- check_target(combat),
         {:ok, weapon_name} <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_neili(character) do
      apply_perform(conn, character, target, stats, weapon_name)
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
    if Combat.busy?(combat),
      do: {:error, "你现在没空！！\n"},
      else: :ok
  end

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (!objectp(weapon = me->query_temp("weapon"))
  #     || (string)weapon->query("skill_type") != "blade")
  #          return notify_fail("你使用的武器不对。\n");
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "blade" do
      {:ok, Map.get(weapon, :name) || ""}
    else
      {:error, "你使用的武器不对。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("hongye-daofa", 1) < 80)
  #          return notify_fail("你目前功力还使不出" LEITING "。\n");
  defp check_skill_level(stats) do
    if Stats.skill(stats, "hongye-daofa") < 80 do
      {:error, "你目前功力还使不出#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 500) return notify_fail("你的内力不够。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你的内力不够。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, stats, weapon_name) do
    # LPC: damage = me->query_skill("hongye-daofa", 1)
    #            + random((int)me->query_skill("dodge")) / 2;
    damage =
      Stats.skill(stats, "hongye-daofa") +
        div(Engine.rand(&:rand.uniform/1, max(Stats.skill(stats, "dodge"), 1)), 2)

    # LPC: msg = HIR "\n$N手中的" + weapon->name() + HIR "幻出漫天刀云，"
    #           + weapon->name() + HIR "划破刀云，雷霆霹雳般的击向$n！\n" NOR;
    # NOTE: weapon->name() 把起手文案拆成三段字面量。
    opening =
      "$N手中的" <>
        weapon_name <>
        "幻出漫天刀云，" <> weapon_name <> "划破刀云，雷霆霹雳般的击向$n！\n"

    conn = Broadcast.publish(conn, opening, n1: character.name, n2: target.name)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        damage: damage,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(10) > 4) { me->add("neili", -50);
    #          msg = do_damage(..., 30, HIC "\n$N刀气好似暴雨前雷霆一般，..."); }
    if Engine.rand(rng, 10) > 4 do
      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 30, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}
      Performs.feedback(attacker, 50, 1)

      conn
      |> Broadcast.publish(
        "\n$N刀气好似暴雨前雷霆一般，夹杂着刺耳的尖鸣，直贯$n而去。\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: message_combatd(HIC "\n$n不退反进，..."; ...); me->start_busy(1)
      Performs.feedback(attacker, 0, 1)

      Broadcast.publish(
        conn,
        "\n$n不退反进，在$N挥刀之前逼到近身，使得$N不得不收回了七成的力道。\n",
        bindings
      )
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "hongye-daofa/leiting",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
