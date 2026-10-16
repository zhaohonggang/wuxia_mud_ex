defmodule Kantele.Combat.Skills.Performs.FeifengWhip.Wu do
  @moduledoc """
  飞凤翔舞「wu」（对照 `kungfu/skill/feifeng-whip/wu.c`，inherit F_SSERVER）

  飞凤鞭法（鞭 whip）攻击绝招：要求真气 >= 200、内功 force >= 100、
  feifeng-whip >= 60、鞭已激发映射；命中判定
  `random(whip) > target_force/2`，命中伤害 `(force+whip)/8` 后
  `+random(damage)`（外伤 30%）。
  注意：LPC 门禁文案写的是「段家剑法」（原文如此，非笔误迁移）。
  命中后追加一次 `do_attack` × 3 连击（TODO）。
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

  @perform_id "feifeng-whip/wu"
  @move_name "「飞凤翔舞」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
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

    if weapon && Map.get(weapon, :skill_type) == "whip" do
      :ok
    else
      {:error, "你使用的武器不对。\n"}
    end
  end

  # LPC: "你的段家剑法不够娴熟，不会使用「飞凤翔舞」。"（原文如此）
  defp check_skill_level(stats) do
    if Stats.skill(stats, "feifeng-whip") < 60 do
      {:error, "你的段家剑法不够娴熟，不会使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 100 do
      {:error, "你的内功修为不够高。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在真气不够，不能使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: "你现在没有激发段家剑，不能使用「飞凤翔舞」。"（原文如此）
  defp check_mapped(stats) do
    if Stats.mapped(stats, "whip") == "feifeng-whip" do
      :ok
    else
      {:error, "你现在没有激发段家剑，不能使用#{@move_name}。\n"}
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

    # LPC: msg = HIY "$N" HIY "身子一晃，手中的" + weapon->name() +
    #           HIY "画了一个圈子，缠向$n" HIY "。\n"NOR;
    # NOTE: weapon->name() 把起始文案拆成两段字面量。
    p1 = "$N身子一晃，手中的"
    p2 = "画了一个圈子，缠向$n。\n"
    start_msg = p1 <> (weapon_name || "") <> p2
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    # LPC: if (random(me->query_skill("whip")) > target->query_skill("force") / 2)
    #      damage = (int)me->query_skill("force") + (int)me->query_skill("whip");
    #      damage = damage / 8; damage += random(damage);
    force = Stats.skill(stats, "force")
    whip = Stats.skill(stats, "whip")
    base = div(force + whip, 8)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: whip,
        dp: Stats.skill(target.meta.stats, "force"),
        base: base,
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
    dp = Map.get(data, :dp, 0)
    base = Map.get(data, :base, 0)
    weapon_name = Map.get(data, :weapon_name)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    if Engine.rand(rng, max(ap, 1)) > div(dp, 2) do
      # LPC: damage += random(damage);
      #      msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 30,
      #        HIR "$n" HIR "只觉得浑身一震，内息有如"
      #        "潮涌，一时不由全身乏力，向后退了一步。\n" NOR);
      damage = base + Engine.rand(rng, max(base, 1))
      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      vitals = Vitals.wound(vitals, :qi, div(damage * 30, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      hit_msg = "$n只觉得浑身一震，内息有如潮涌，一时不由全身乏力，向后退了一步。\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      # LPC: msg += HIY "\n$N" HIY "见状，手中" + weapon->name() + HIY +
      #            "急挥，一连数招攻向$n" HIY "！\n" NOR;
      # NOTE: weapon->name() 把追加文案拆成两段字面量。
      f1 = "\n$N见状，手中"
      f2 = "急挥，一连数招攻向$n！\n"
      follow_msg = f1 <> (weapon_name || "") <> f2
      conn = Broadcast.publish(conn, follow_msg, n1: attacker.name, n2: character.name)

      # LPC: for (i = 0; i < 3; i++) ... COMBAT_D->do_attack(me, target, weapon, 0);
      #      me->start_busy(1 + random(3)); me->add("neili", -50);
      # TODO: 三次 do_attack 连击对应 Engine.attack_round/3，需 Fighter 转换后调用。
      Performs.feedback(attacker, 50, 1 + Engine.rand(rng, 3))

      conn
      |> put_character(character)
    else
      # LPC: msg += CYN "可是$p" CYN "轻轻架开$P" CYN
      #            "这一招，似乎并没有废多少气力。\n" NOR;
      #      me->add("neili", -70); me->start_busy(3);
      miss_msg = "可是$p轻轻架开$P这一招，似乎并没有废多少气力。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 70, 3)

      conn
      |> put_character(character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
