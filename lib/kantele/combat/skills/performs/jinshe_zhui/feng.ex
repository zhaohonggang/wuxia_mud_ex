defmodule Kantele.Combat.Skills.Performs.JinsheZhui.Feng do
  @moduledoc """
  perform「截脉封穴」（source jinshe-zhui/feng.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：自身冷却（jinshe/feng）→ 目标为战斗中的对手 →
  内功>=150 → 金蛇锥法>=100 → 真气>=500 → 激发 throwing 为金蛇锥法 →
  目标存活。（`.c` 无 `can_perform`，故不设「已知此招」检查。）
  起手广播后按 `ap/2 + random(ap) > 目标 force` 判定：命中则给目标施加
  `random(6)` 选中的属性 debuff（`apply/damage -skill/6` 或
  `apply/{dodge,parry,force,armor,defense} -skill/4`，叠加、不自动消除），
  攻击方扣 200 真气 / 忙乱 1，播报「点中要穴…瘫倒」；
  未命中攻击方扣 50 真气 / 忙乱 3，播报「看破…拆解」。

  差异（TODO(migrate)）：
  - `.c` 的 `me->set_temp("jinshe/feng",1)`（命中后置 5 秒冷却）此处简化为
    起手即给攻击方加 5 秒冷却 buff（命中/失手均进入冷却），文案与时限保留；
  - 命中判定需目标 `force`，故在目标侧结算；攻击方消耗/忙乱经
    `Performs.feedback/3` 回传；
  - 目标 debuff（apply/X）按 `.c` 为永久性（feng_end 仅删 jinshe/feng 冷却，
    不回撤 apply 减益），此处仅 `apply_temp` 不挂过期 buff；
    `apply/force` 非本引擎 @applies_keys 白名单键，仅入 temp 不实际生效。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "jinshe-zhui/feng"
  @move_name "「截脉封穴」"
  @cooldown_secs 5

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jinshe-zhui")
    ap = Stats.skill(stats, "throwing")

    with :ok <- check_jinshe_feng(combat),
         {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character),
         :ok <- check_target_alive(target) do
      # .c: me->set_temp("jinshe/feng", 1)（命中后置冷却）→ 简化为起手即置冷却 buff
      cooldown = %Combat.Buff{key: "jinshe/feng", applies: %{}, duration: @cooldown_secs}
      combat = Combat.add_buff(combat, cooldown)
      character = %{character | meta: %{character.meta | combat: combat}}
      conn = put_character(conn, character)

      Process.send_after(
        self(),
        %Event{
          from_pid: self(),
          topic: "combat/buff-expire",
          data: %{key: "jinshe/feng", applies: %{}}
        },
        @cooldown_secs * 1000
      )

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
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

  # LPC: if (me->query_temp("jinshe/feng"))
  #          return notify_fail("你才用过截脉封穴，没法接着就出招。\n");
  defp check_jinshe_feng(combat) do
    if Combat.buff_active?(combat, "jinshe/feng") do
      {:error, "你才用过截脉封穴，没法接着就出招。\n"}
    else
      :ok
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  #          return notify_fail("截脉封穴只能在战斗中使用。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "截脉封穴只能在战斗中使用。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 150)
  #          return notify_fail("你的内功的修为不够，难以施展" FENG "。\n");
  #      if (skill < 100)
  #          return notify_fail("你的金蛇锥法修为有限，难以施展" FENG "。\n");
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功的修为不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "jinshe-zhui") < 100 ->
        {:error, "你的金蛇锥法修为有限，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("neili") < 500)
  #          return notify_fail("你现在的真气不足，难以施展" FENG "。\n");
  defp check_resources(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("throwing") != "jinshe-zhui")
  #          return notify_fail("你没有激发金蛇锥法，难以施展" FENG "。\n");
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "throwing") == "jinshe-zhui" do
      :ok
    else
      {:error, "你没有激发金蛇锥法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: msg = HIR "$N" HIR "飞身一跃而起，贴至$n" HIR "跟前，点向$n"
  #           HIR "要穴！\n" NOR; message_combatd(msg, me, target);
  defp apply_effect(conn, character, target) do
    conn
    |> Broadcast.publish(
      "$N飞身一跃而起，贴至$n跟前，点向$n要穴！\n",
      n1: character.name,
      n2: target.name
    )
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
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
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    skill = max(Map.get(data, :skill, 0), 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force");
    #      if (ap / 2 + random(ap) > dp)
    dp = Stats.skill(stats, "force")

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: switch (random(6)) { case 0: apply/damage -skill/6;
      #        case 1..4: apply/X -skill/4; default: apply/defense -skill/4; }
      {key, amount} =
        case Engine.rand(rng, 6) do
          0 -> {:damage, div(skill, 6)}
          1 -> {:dodge, div(skill, 4)}
          2 -> {:parry, div(skill, 4)}
          3 -> {:force, div(skill, 4)}
          4 -> {:armor, div(skill, 4)}
          _ -> {:defense, div(skill, 4)}
        end

      # LPC: target->add_temp("apply/X", -amount); （永久性，不挂过期 buff）
      combat = Combat.apply_temp(character.meta.combat, %{key => -amount})
      character = %{character | meta: %{character.meta | combat: combat}}

      # LPC: me->add("neili", -200); me->start_busy(1);
      #      msg += "$p微微一楞，已被$N点中要穴，顿时瘫软无力，缓缓瘫倒。\n";
      Performs.feedback(attacker, 200, 1)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$p微微一楞，已被$N点中要穴，顿时瘫软无力，缓缓瘫倒。\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: me->add("neili", -50); me->start_busy(3);
      #      msg += "可是$p的看破了$P的招式，巧妙的一一拆解，没露半点破绽！\n";
      Performs.feedback(attacker, 50, 3)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "可是$p的看破了$P的招式，巧妙的一一拆解，没露半点破绽！\n",
          bindings
        )
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define FENG "「" HIR "截脉封穴" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me)
  # {
  #         string msg;
  #         object target, anqi;
  #         int skill, count, ap, dp;
  # 
  #         //anqi = me->query_temp("handing");
  #         skill = me->query_skill("jinshe-zhui", 1);
  # 
  #         if (! objectp(anqi = me->query_temp("handing"))
  #            || (string)anqi->query("skill_type") != "throwing")
  #         {
  #             count = 0;
  #         }    else
  #         {
  #             count = anqi->query("weapon_prop/damage");
  #         }
  # 
  #         if (me->query_temp("jinshe/feng"))
  #         return notify_fail("你才用过截脉封穴，没法接着就出招。\n");
  # 
  #         if (! target) target = offensive_target(me);
  #         if (! target ||    ! me->is_fighting(target))
  #         return notify_fail("截脉封穴只能在战斗中使用。\n");
  # 
  #         if (me->query_skill("force") < 150)
  #                 return notify_fail("你的内功的修为不够，难以施展" FENG "。\n");
  # 
  #         if (skill < 100)
  #                 return notify_fail("你的金蛇锥法修为有限，难以施展" FENG "。\n");
  # 
  #         if (me->query("neili") < 500)
  #                 return notify_fail("你现在的真气不足，难以施展" FENG "。\n");
  # 
  #         if (me->query_skill_mapped("throwing") != "jinshe-zhui")
  #                 return notify_fail("你没有激发金蛇锥法，难以施展" FENG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "飞身一跃而起，贴至$n" HIR "跟前，点向$n" HIR "要穴！\n" NOR;
  # 
  #         ap = me->query_skill("throwing");
  #         dp = target->query_skill("force");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  # 
  #             msg += HIR "$p" HIR "微微一楞，已被$N" HIR
  #                 "点中要穴，顿时瘫软无力，缓缓瘫倒。\n" NOR;
  #                 me->add("neili", -200);
  #                 me->start_busy(1);
  #                 me->set_temp("jinshe/feng", 1);
  #                 me->start_call_out((: call_other, __FILE__, "feng_end", me :), 5);
  # 
  #                 switch (random(6))
  #                 {
  #                     case 0:
  #                             target->add_temp("apply/damage", -skill / 6);
  #                             break;
  # 
  #                     case 1:
  #                             target->add_temp("apply/dodge", -skill / 4);
  #                             break;
  # 
  #                     case 2:
  #                             target->add_temp("apply/parry", -skill / 4);
  #                             break;
  # 
  #                     case 3:
  #                             target->add_temp("apply/force", -skill / 4);
  #                             break;
  # 
  #                     case 4:
  #                             target->add_temp("apply/armor", -skill / 4);
  #                             break;
  # 
  #                     default:
  #                             target->add_temp("apply/defense", -skill / 4);
  #                             break;
  #                 }
  # 
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "的看破了$P" CYN
  #                        "的招式，巧妙的一一拆解，没露半点破绽！\n" NOR;
  #                 me->add("neili", -50);
  #                 me->start_busy(3);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
  # 
  # void feng_end(object me)
  # {
  #         me->delete_temp("jinshe/feng");
  # }
end
