defmodule Kantele.Combat.Skills.Performs.DuoluoyeZhi.Jimie do
  @moduledoc """
  菩提寂灭「jimie」（对照 `kungfu/skill/duoluoye-zhi/jimie.c`，inherit F_SSERVER）

  少林多罗叶指（空手）绝招：要求空手、force >= 200、duoluoye-zhi >= 180、
  真气 >= 800 且 max_neili >= 2500、finger 已激发映射；命中判定
  `ap/2 + random(ap) > dp`，其中 `ap = finger + duoluoye-zhi`，
  `dp = dodge + force`；命中伤害 `damage = random(ap) + ap`（外伤 70%）。
  LPC 另有无条件追加的收束文案与施招者自伤 `damage/4`。
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

  @perform_id "duoluoye-zhi/jimie"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with {:ok, target} <- target(combat),
         :ok <- check_unarmed(combat),
         :ok <- check_force(stats),
         :ok <- check_skill_level(stats),
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
      [] -> {:error, "「菩提寂灭」只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #          return notify_fail("你必须空手才能使用「菩提寂灭」！\n");
  defp check_unarmed(combat) do
    weapon = Combat.weapon(combat)
    secondary = Map.get(combat.equipped, :secondary_weapon)

    if weapon || secondary do
      {:error, "你必须空手才能使用「菩提寂灭」！\n"}
    else
      :ok
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 200 do
      {:error, "你的内功的修为不够，不能使用这一绝技！\n"}
    else
      :ok
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "duoluoye-zhi") < 180 do
      {:error, "你的多罗叶指修为不够，目前不能使用「菩提寂灭」！\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 800 or character.meta.vitals.max_neili < 2500 do
      {:error, "你的真气不够，无法使用「菩提寂灭」！\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "finger") == "duoluoye-zhi" do
      :ok
    else
      {:error, "你没有激发多罗叶指，不能使用「菩提寂灭」！\n"}
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
    # LPC: msg = HIB "$N" HIB "运起全身功力，直扑向$n" + HIB "，双手一圈，用一股内劲" +
    #           "拖住$n，" + HIB "随即全力一指戳出，不惜耗费大量真元，力求一击毙敌！\n" NOR;
    # NOTE: 四段之间均为 + 拼接 → 四个独立字面量。
    s1 = "$N运起全身功力，直扑向$n"
    s2 = "，双手一圈，用一股内劲"
    s3 = "拖住$n，"
    s4 = "随即全力一指戳出，不惜耗费大量真元，力求一击毙敌！\n"
    start_msg = s1 <> s2 <> s3 <> s4
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    # LPC: msg += HIR "而$P" + HIR "由于内力提升过度，经脉负荷不" + "了，受了不轻的内伤！\n" NOR;
    #      me->receive_damage("qi", damage / 4);
    # NOTE: 该段与自伤在 C 中均位于 hit/miss 分支之后、无条件执行；此处一并在
    #       施招方进程落实（与命中/落空消息的显示顺序因此提前，属已知差异）。
    q1 = "而$P"
    q2 = "由于内力提升过度，经脉负荷不"
    q3 = "了，受了不轻的内伤！\n"
    post_msg = q1 <> q2 <> q3
    conn = Broadcast.publish(conn, post_msg, n1: character.name, n2: target.name)

    # LPC: ap = finger + duoluoye-zhi; dp = dodge + force; damage = random(ap) + ap;
    ap = Stats.skill(stats, "finger") + Stats.skill(stats, "duoluoye-zhi")
    dp = Stats.skill(target.meta.stats, "dodge") + Stats.skill(target.meta.stats, "force")
    damage = Engine.rand(&:rand.uniform/1, max(ap, 1)) + ap

    # LPC: me->receive_damage("qi", damage / 4); —— 施招者自伤
    vitals = Vitals.damage(character.meta.vitals, :qi, div(damage, 4))
    character = %{character | meta: %{character.meta | vitals: vitals}}

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: ap,
        dp: dp,
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
    ap = Map.get(data, :ap, 0)
    dp = Map.get(data, :dp, 0)
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      # LPC: msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
      #        HIR "只见$p" HIR "一声惨号，已被$P" + HIR "一指击中，一股霸道的内力由$P" +
      #        HIR "的指尖传来，伤及经脉！\n" NOR);
      #      me->add("neili", -500); me->start_busy(2);
      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      vitals = Vitals.wound(vitals, :qi, div(damage * 70, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      # NOTE: 第一段为相邻拼接的单字面量，后两段以 + 分隔。
      h1 = "只见$p一声惨号，已被$P"
      h2 = "一指击中，一股霸道的内力由$P"
      h3 = "的指尖传来，伤及经脉！\n"
      hit_msg = h1 <> h2 <> h3
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 500, 2)

      conn
      |> put_character(character)
    else
      # LPC: msg += CYN "可是$p" CYN "内力深厚，及时摆脱了"
      #            CYN "$P" CYN "内力的牵扯，躲开了这一击！\n" NOR;
      #      me->add("neili", -200); me->start_busy(3);
      miss_msg = "可是$p内力深厚，及时摆脱了$P内力的牵扯，躲开了这一击！\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 200, 3)

      conn
      |> put_character(character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
