defmodule Kantele.Combat.Skills.Performs.PuduZhang.Zhao do
  @moduledoc """
  perform「佛光普照」（对照 `kungfu/skill/pudu-zhang/zhao.c`）

  门槛（按 .c 顺序）：战斗中的对手 → 武器为 staff（文案**不带绝招名**）→
  内功>=200 → 普渡杖法>=135 → 真气>=1000 → 激发 staff 为普渡杖法 →
  目标存活。（`.c` 无 `can_perform` 门槛，故无「已学此招」检查。）
  起手广播（带武器名）后由目标侧单次判定
  `ap/2 + random(ap) > dp`（`ap = 杖法 + 自身内力上限/10`、
  `dp = 目标内功 + 目标内力上限/10`）：命中则
  `damage = max(自身内力上限 - 目标内力上限, 0)/5 + 杖法/2 + random(damage/3)`、
  外伤比例 50、攻击方扣 250 真气并忙乱 2；未命中则扣 60 真气并忙乱 3。
  两种消耗都依赖命中结果，故经 `Performs.feedback(attacker, neili, busy)`
  在目标侧回授。

  差异（TODO(migrate)）：
  - `.c` 起手文案 `"…挥动手中的" + wn + "，如泰山一般压向$n" + HIY "，令人叹为观止！\n"`
    是**三段**字面量（剥色后中间两段只被 `+` 分隔，`join_adjacent` 不合并），
    E 侧用 list + `Enum.join("")` 保持同样三段（`<>` 会把相邻纯字面量合成一段）；
  - `damage` 需要目标 `max_neili`，故该式在目标侧计算；自身 `max_neili` 与
    杖法等级经 event data 由攻击方传入；
  - `.c` 的 `me->query("max_neili") / 10`、`damage / 5` 等整数除法按 C 语义
    截断（Elixir `div/2` 同样截断）；
  - `.c` 起手与分支文案分两次发布（都累加进同一 `msg` 后一次
    `message_combatd`）；E 侧拆两处——起手在攻击方发布，分支文案在目标侧发布
    （`dp` 需目标属性）；
  - 未命中文案里的 `$p`/`$P` 分别指目标与攻击方
    （`$n/$p → :n2`、`$N/$P → :n1`）；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧
    `combat/perform-incoming` 的死亡检查兜底。
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
  alias Kantele.Combat.Performs

  @perform_id "pudu-zhang/zhao"
  @move_name "「佛光普照」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    vitals = character.meta.vitals
    rng = &:rand.uniform/1

    # LPC: ap = me->query_skill("staff") + me->query("max_neili") / 10;
    ap = Stats.skill(stats, "staff") + div(vitals.max_neili, 10)

    # LPC: damage = me->query("max_neili") - target->query("max_neili");
    #      damage = damage / 5 + me->query_skill("staff") / 2;
    #      damage += random(damage / 3);
    # 其中目标 max_neili 在目标侧，故自身 max_neili 与杖法等级经 data 传入。
    max_neili = vitals.max_neili
    staff = Stats.skill(stats, "staff")

    with {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
          max_neili: max_neili,
          staff: staff,
          rng: rng
        }
      })

      apply_effect(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #           (string)weapon->query("skill_type") != "staff")
  #      return notify_fail("你使用的武器不对。\n");
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon != nil and Map.get(weapon, :skill_type) == "staff" do
      :ok
    else
      {:error, "你使用的武器不对。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 200)
  #      if (me->query_skill("pudu-zhang", 1) < 135)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 200 ->
        {:error, "你的内功的修为不够，不能使用这一绝技！\n"}

      Stats.skill(stats, "pudu-zhang") < 135 ->
        {:error, "你的普渡杖法修为不够，目前不能使用佛光普照！\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("neili") < 1000)
  defp check_resources(character) do
    if character.meta.vitals.neili < 1000 do
      {:error, "你的真气不够，不能使用佛光普照！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("staff") != "pudu-zhang")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "staff") == "pudu-zhang" do
      :ok
    else
      {:error, "你没有激发普渡杖法，不能使用佛光普照！\n"}
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp weapon_name(combat) do
    case Combat.weapon(combat) do
      nil -> ""
      weapon -> Map.get(weapon, :name)
    end
  end

  # LPC: msg = HIY "$N" HIY "纵声长笑，挥动手中的" + weapon->name() +
  #            HIY "，如泰山一般压向$n" + HIY "，令人叹为观止！\n" NOR;
  #      …分支与消耗都在目标侧结算…
  # .c 的三段字面量（中间只被 + 分隔）用 list + Enum.join 保持原样。
  defp apply_effect(conn, character, target) do
    Broadcast.publish(
      conn,
      [
        "$N纵声长笑，挥动手中的" <> weapon_name(character.meta.combat),
        "，如泰山一般压向$n",
        "，令人叹为观止！\n"
      ] |> Enum.join(""),
      n1: character.name,
      n2: target.name
    )
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # .c 的 !living(target) 在攻击方无 meta 可查，由此处死亡检查兜底。
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    max_neili = Map.get(data, :max_neili, 0)
    staff = Map.get(data, :staff, 0)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force") + target->query("max_neili") / 10;
    dp =
      Stats.skill(character.meta.stats, "force") +
        div(character.meta.vitals.max_neili, 10)

    # LPC: if (ap / 2 + random(ap) > dp)
    #      { damage = me->query("max_neili") - target->query("max_neili");
    #        if (damage < 0) damage = 0;
    #        damage = damage / 5 + me->query_skill("staff") / 2;
    #        damage += random(damage / 3);
    #        me->add("neili", -250);
    #        msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
    #                                   HIR "只见$p" HIR "闷哼一声，连叫都叫"
    #                                   "不出来，身子飞跌出去，重重的摔倒在地上！\n" NOR);
    #        me->start_busy(2); }
    #      else
    #      { me->add("neili", -60);
    #        me->start_busy(3);
    #        msg += CYN "可是$p" CYN "运足内力，奋力挡住了"
    #               CYN "$P" CYN "这惊天动地的一击！\n"NOR; }
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = max_neili - target->max_neili（<0 归零）后 /5 + staff/2 + random(damage/3)
      damage = max(max_neili - character.meta.vitals.max_neili, 0)
      damage = div(damage, 5) + div(staff, 2)
      damage = damage + Engine.rand(rng, div(damage, 3))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 50, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: me->add("neili", -250);  me->start_busy(2);
      Performs.feedback(attacker, 250, 2)

      conn
      |> Broadcast.publish(
        "只见$p闷哼一声，连叫都叫不出来，身子飞跌出去，重重的摔倒在地上！\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: me->add("neili", -60);  me->start_busy(3);
      Performs.feedback(attacker, 60, 3)

      conn
      |> Broadcast.publish(
        "可是$p运足内力，奋力挡住了$P这惊天动地的一击！\n",
        bindings
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // zhao.c 佛光普照
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #             return notify_fail("「佛光普照」只能在战斗中对对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "staff")
  #         return notify_fail("你使用的武器不对。\n");
  # 
  #     if (me->query_skill("force") < 200)
  #         return notify_fail("你的内功的修为不够，不能使用这一绝技！\n");
  # 
  #     if (me->query_skill("pudu-zhang", 1) < 135)
  #         return notify_fail("你的普渡杖法修为不够，目前不能使用佛光普照！\n");
  # 
  #     if (me->query("neili") < 1000)
  #         return notify_fail("你的真气不够，不能使用佛光普照！\n");
  # 
  #         if (me->query_skill_mapped("staff") != "pudu-zhang")
  #                 return notify_fail("你没有激发普渡杖法，不能使用佛光普照！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "纵声长笑，挥动手中的" + weapon->name() +
  #               HIY "，如泰山一般压向$n" + HIY "，令人叹为观止！\n" NOR;
  # 
  #         ap = me->query_skill("staff") + me->query("max_neili") / 10;
  #         dp = target->query_skill("force") + target->query("max_neili") / 10;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = me->query("max_neili") - target->query("max_neili");
  #                 if (damage < 0) damage = 0;
  #                 damage = damage / 5 + me->query_skill("staff") / 2;
  #                 damage += random(damage / 3);
  #                 me->add("neili", -250);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
  #                                            HIR "只见$p" HIR "闷哼一声，连叫都叫"
  #                                            "不出来，身子飞跌出去，重重的摔倒在地上！\n" NOR);
  #                 me->start_busy(2);
  #         } else
  #         {
  #                 me->add("neili", -60);
  #                 me->start_busy(3);
  #                 msg += CYN "可是$p" CYN "运足内力，奋力挡住了"
  #                        CYN "$P" CYN "这惊天动地的一击！\n"NOR;
  #         }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
