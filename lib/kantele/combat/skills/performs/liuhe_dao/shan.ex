defmodule Kantele.Combat.Skills.Performs.LiuheDao.Shan do
  @moduledoc """
  闪刀诀「shan」（对照 `kungfu/skill/liuhe-dao/shan.c`，inherit F_SSERVER）

  六合刀法（刀 blade）攻击绝招：要求内力 >= 150、内功 force >= 100、
  liuhe-dao >= 80、刀已激发映射；按 blade 与 parry 判定命中（外伤 35%）。
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

  @perform_id "liuhe-dao/shan"
  @move_name "「闪刀诀」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_force(stats),
         :ok <- check_skill_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
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

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "blade" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 100 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "liuhe-dao") < 80 do
      {:error, "你的六合刀法还不到家，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "blade") == "liuhe-dao" do
      :ok
    else
      {:error, "你没有激发六合刀法，难以施展#{@move_name}。\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, stats) do
    combat = character.meta.combat
    weapon = Combat.weapon(combat)
    weapon_name = weapon && Map.get(weapon, :name)

    # LPC: msg = HIW "$N" HIW "手中的" + weapon->name() + HIW "吞吐不定，接连"
    #           "变换了数种方位，最后呼的一声朝$n" HIW "砍落！\n" NOR;
    # NOTE: weapon->name() 把起始文案拆成两段独立字面量。
    p1 = "$N手中的"
    p2 = "吞吐不定，接连变换了数种方位，最后呼的一声朝$n砍落！\n"
    start_msg = p1 <> (weapon_name || "") <> p2
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    ap = Stats.skill(stats, "blade")
    dp = Stats.skill(target.meta.stats, "parry")

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: ap,
        dp: dp,
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
    dp = Map.get(data, :dp, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      # LPC: damage = ap/2 + random(ap/2);
      #      msg += do_damage(me, target, WEAPON_ATTACK, damage, 35,
      #        HIR "只见$n" HIR "招架不及，顿时被$N"
      #        HIR "这一刀砍中要害，伤口见骨，鲜血狂溅！\n" NOR);
      #      me->add("neili", -100); me->start_busy(2);
      damage = div(ap, 2) + Engine.rand(rng, max(div(ap, 2), 1))
      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      vitals = Vitals.wound(vitals, :qi, div(damage * 35, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      hit_msg = "只见$n招架不及，顿时被$N这一刀砍中要害，伤口见骨，鲜血狂溅！\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 100, 2)

      conn
      |> put_character(character)
    else
      # LPC: msg += CYN "可是$p" CYN "凝神聚气，护住门户，无论$P"
      #            CYN "怎样变招，始终奈何不得。\n" NOR;
      #      me->add("neili", -50); me->start_busy(3);
      miss_msg = "可是$p凝神聚气，护住门户，无论$P怎样变招，始终奈何不得。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 50, 3)

      conn
      |> put_character(character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
