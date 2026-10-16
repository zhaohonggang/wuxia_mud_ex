defmodule Kantele.Combat.Skills.Performs.HenshanJian.Huan do
  @moduledoc """
  幻剑式「huan」（对照 `kungfu/skill/henshan-jian/huan.c`，inherit F_SSERVER）

  衡山剑法攻击绝招：要求持 sword 类武器、henshan-jian >= 60、
  mapped("sword") == "henshan-jian"、force >= 80、真气 >= 50；
  攻击方广播起手式并发 `combat/perform-incoming`，目标侧按
  `ap/2 + rand(ap) > dp`（ap=sword，dp=parry）判定：
  - 命中：伤害 `ap/3 + rand(ap/2)`（10% 外伤），扣 50 内力、忙乱 2；
  - 未中：扣 30 内力、忙乱 2。
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

  @perform_id "henshan-jian/huan"
  @move_name "「幻剑式」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon_name} <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
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

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon"))
  #     || (string)weapon->query("skill_type") != "sword")
  #          return notify_fail("你所使用的武器不对，难以施展" HUAN "。\n");
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, Map.get(weapon, :name) || ""}
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("henshan-jian", 1) < 60)
  #          return notify_fail("你衡山剑法不够娴熟，难以施展" HUAN "。\n");
  defp check_skill_level(stats) do
    if Stats.skill(stats, "henshan-jian") < 60 do
      {:error, "你衡山剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "henshan-jian")
  #          return notify_fail("你没有激发衡山剑法，难以施展" HUAN "。\n");
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "henshan-jian" do
      :ok
    else
      {:error, "你没有激发衡山剑法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("force") < 80)
  #          return notify_fail("你的内功火候不够，难以施展" HUAN "。\n");
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 80 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 50)
  #          return notify_fail("你现在的真气不够，难以施展" HUAN "。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 50 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_target_alive(target) do
    if not dead?(target),
      do: :ok,
      else: {:error, "对方都已经这样了，用不着这么费力吧？\n"}
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, stats, weapon_name) do
    ap = Stats.skill(stats, "sword")

    # LPC: msg = HIC "\n$N" HIC "将真气运于剑身，身法陡然加快，手中" + wn +
    #           HIC "剑随人动，霎那间剑光四散，如梦如幻，像有无数柄" + wn +
    #           HIC "一齐袭向$n" HIC "。" NOR;
    # NOTE: wn（weapon->name()）把起手文案拆成三段字面量。
    opening =
      "$N将真气运于剑身，身法陡然加快，手中" <>
        weapon_name <>
        "剑随人动，霎那间剑光四散，如梦如幻，像有无数柄" <>
        weapon_name <> "一齐袭向$n。"

    conn = Broadcast.publish(conn, opening, n1: character.name, n2: target.name)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: ap,
        weapon_name: weapon_name,
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
    ap = Map.get(data, :ap, 0)
    weapon_name = Map.get(data, :weapon_name) || ""
    rng = Map.get(data, :rng, &:rand.uniform/1)
    dp = Stats.skill(character.meta.stats, "parry")

    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      # LPC: damage = ap / 3 + random(ap / 2);
      #      do_damage(me, target, WEAPON_ATTACK, damage, 10, HIR "$n" ... );
      damage = div(ap, 3) + Engine.rand(rng, max(div(ap, 2), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 10, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}
      Performs.feedback(attacker, 50, 2)

      # LPC: HIR "$n" HIR "看得眼花缭乱，却分不清" "剑的来路，肩膀已被"
      #      + wn + HIR "刺出" "一个窟窿。\n" NOR;
      hit_msg = "$n看得眼花缭乱，却分不清剑的来路，肩膀已被" <> weapon_name <> "刺出一个窟窿。\n"

      conn
      |> Broadcast.publish(hit_msg, bindings)
      |> put_character(character)
    else
      # LPC: msg = CYN "然而$n" CYN "并未受幻象所困，侧身一跳" "躲过$N"
      #           CYN "这一剑。\n" NOR; me->add("neili", -30); me->start_busy(2)
      Performs.feedback(attacker, 30, 2)

      Broadcast.publish(
        conn,
        "然而$n并未受幻象所困，侧身一跳躲过$N这一剑。\n",
        bindings
      )
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
