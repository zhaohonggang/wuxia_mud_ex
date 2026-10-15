defmodule Kantele.Combat.Skills.Performs.QianyeShou.Qianye do
  @moduledoc """
  千叶佛手「qianye」（对照 `kungfu/skill/qianye-shou/qianye.c`）

  千叶手绝技：需千叶手>=120、真气>=100、激发 hand 为千叶手、目标存活。
  命中判定 `ap/2 + random(ap) > 目标(parry+dodge)`
  （`ap = 内功 + 手法`）：命中扣 100 真气、忙乱 1，造成
  `40 + ap/10 + random(ap/10)`（外伤 35%）；若 `ap/3 + random(ap) > 目标防御`
  且目标未忙，则令目标忙乱 `ap/50 + 2`。未命中扣 30 真气、忙乱 3。

  差异（TODO(migrate)）：
  - `.c` 无 `can_perform` 门槛，本引擎保留 `perform_known?` 守卫（多 1 条信息性 EXTRA）；
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - 攻击方真气/忙乱经 `Performs.feedback/3` 由目标侧回传。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "qianye-shou/qianye"
  @move_name "「千叶佛手」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat
    rng = &:rand.uniform/1
    level = Stats.skill(stats, "qianye-shou")
    ap = Stats.skill(stats, "force") + Stats.skill(stats, "hand")

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_skill_level(level),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: level,
          ap: ap,
          rng: rng
        }
      })

      apply_perform(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC 无 can_perform 门槛；本引擎保留已知绝招守卫（信息性 EXTRA）。
  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: skill = me->query_skill("qianye-shou", 1); if (skill < 120)
  defp check_skill_level(level) do
    if level < 120 do
      {:error, "你的千叶手等级不够，不会使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 100)
  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你的真气不够，无法运用#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("hand") != "qianye-shou")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "hand") == "qianye-shou" do
      :ok
    else
      {:error, "你没有激发千叶手，无法使用#{@move_name}！\n"}
    end
  end

  defp apply_perform(conn, character, target) do
    # LPC: msg = HIC "$N" HIC "倏的靠近$n" HIC "，伸手一晃，"
    #           "化出无数掌影，如同你有千百只手一齐攻向" HIC "$n！\n" NOR;
    conn
    |> Broadcast.publish(
      "$N倏的靠近$n，伸手一晃，化出无数掌影，如同你有千百只手一齐攻向$n！\n",
      n1: character.name,
      n2: target.name
    )
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？\n",
        n1: attacker.name,
        n2: character.name
      )
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry") + target->query_skill("dodge");
    dp = Stats.skill(stats, "parry") + Stats.skill(stats, "dodge")

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = 40 + ap / 10 + random(ap / 10);
      #      me->add("neili", -100); me->start_busy(1);
      #      do_damage(me, target, UNARMED_ATTACK, damage, 35, HIR "...");
      damage = 40 + div(ap, 10) + Engine.rand(rng, max(div(ap, 10), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 35, 100))

      # LPC: if (ap / 3 + random(ap) > dp && ! target->is_busy())
      #          target->start_busy(ap / 50 + 2);
      combat =
        if div(ap, 3) + Engine.rand(rng, ap) > dp and character.meta.combat.busy <= 0 do
          Combat.start_busy(character.meta.combat, div(ap, 50) + 2)
        else
          character.meta.combat
        end

      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "$p既不能招架，又无法躲避，结果被$P连击带打，弄的晕头转向，身上也是伤痕累累。\n",
            bindings
          )
        )

      Performs.feedback(attacker, 100, 1)
      put_character(conn, character)
    else
      # LPC: me->add("neili", -30); me->start_busy(3);
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "可是$p的看破了$P的招式，连消带打，全然化解了$P的攻势。\n",
            bindings
          )
        )

      Performs.feedback(attacker, 30, 3)
      conn
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "qianye-shou/qianye",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // qianye.c 千叶佛手
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me)
  # {
  #     string msg;
  #     object target;
  #     int skill, ap, dp, damage;
  # 
  #   if (! target)
  #   {
  #     me->clean_up_enemy();
  #     target = me->select_opponent();
  #   }
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("「千叶佛手」只能在战斗中对对手使用。\n");
  # 
  #     skill = me->query_skill("qianye-shou", 1);
  # 
  #     if (skill < 120)
  #         return notify_fail("你的千叶手等级不够，不会使用「千叶佛手」！\n");
  # 
  #     if (me->query("neili") < 100)
  #         return notify_fail("你的真气不够，无法运用「千叶佛手」！\n");
  # 
  #     if (me->query_skill_mapped("hand") != "qianye-shou")
  #         return notify_fail("你没有激发千叶手，无法使用「千叶佛手」！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIC "$N" HIC "倏的靠近$n" HIC "，伸手一晃，"
  #           "化出无数掌影，如同你有千百只手一齐攻向" HIC
  #               "$n！\n" NOR;
  # 
  #     ap = me->query_skill("force") + me->query_skill("hand");
  #     dp = target->query_skill("parry") + target->query_skill("dodge");
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #         me->add("neili", -100);
  #         damage = 40 + ap / 10 + random(ap / 10);
  #         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 35,
  #                                            HIR "$p" HIR "既不能招架，又无法躲避，结果被$P"
  #                                            HIR "连击带打，弄的晕头转向，身上也是伤痕累累。\n" NOR);
  #         me->start_busy(1);
  #                 if (ap / 3 + random(ap) > dp && ! target->is_busy())
  #                         target->start_busy(ap / 50 + 2);
  #     } else
  #     {
  #         msg += CYN "可是$p" CYN "的看破了$P" CYN
  #                        "的招式，连消带打，全然化解了$P"
  #                        CYN "的攻势。\n" NOR;
  #         me->add("neili",-30);
  #         me->start_busy(3);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
