defmodule Kantele.Combat.Skills.Performs.RaozhiRoujian.Chuan do
  @moduledoc """
  柔月穿空「chuan」（对照 `kungfu/skill/raozhi-roujian/chuan.c`）

  绕指柔剑单体攻击：需持剑、内功>=150、绕指柔剑>=100、激发 sword 为绕指柔剑、
  真气>=250、目标存活。命中判定
  `ap/2 + random(ap) > 目标parry`（ap = sword）：命中造成
  `ap/2 + random(ap)`（外伤 30%）并扣 150 真气、忙乱 2；
  未命中扣 60 真气、忙乱 3。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - 引子走 `message_sort`，本引擎统一 `Broadcast.publish`；结果段走目标侧结算。
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

  @perform_id "raozhi-roujian/chuan"
  @move_name "「柔月穿空」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_force(stats),
         :ok <- check_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_neili(character) do
      apply_perform(conn, character, target, weapon, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/raozhi-roujian/chuankong"))
  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #           (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 150)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你的内功的修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("raozhi-roujian", 1) < 100)
  defp check_level(stats) do
    if Stats.skill(stats, "raozhi-roujian") < 100 do
      {:error, "你的绕指柔剑修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "raozhi-roujian")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "raozhi-roujian" do
      :ok
    else
      {:error, "你没有激发绕指柔剑，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query("neili") < 250)
  defp check_neili(character) do
    if character.meta.vitals.neili < 250 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, weapon, stats) do
    weapon_name = Map.get(weapon, :name, "")

    # LPC: message_sort(HIM "\n只见$N" HIM "暮地里一声清啸，剑法忽变，那"
    #           "柄" + wn + HIM "竟似成了一条软带，…右肩，招式精奇之极。\n" NOR, me, target);
    #      ap = me->query_skill("sword"); dp = target->query_skill("parry");
    conn =
      Broadcast.publish(
        conn,
        "\n只见$N暮地里一声清啸，剑法忽变，那柄" <>
          weapon_name <>
          "竟似成了一条软带，轻柔曲折，飘忽不定，疾刺$n胸膛，剑到中途，剑尖微颤，竟然弯了过去斜刺$n右肩，招式精奇之极。\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: Stats.skill(stats, "sword"),
        rng: &:rand.uniform/1
      }
    })

    conn
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
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: ap = me->query_skill("sword"); dp = target->query_skill("parry");
    ap = max(Map.get(data, :ap, 0), 1)
    dp = Stats.skill(stats, "parry")

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap / 2 + random(ap); do_damage(..., damage, 30, ...);
      #      me->start_busy(2); me->add("neili", -150);
      damage = div(ap, 2) + Engine.rand(rng, ap)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 30, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "结果$p一个不慎，登被$P剑招刺中，一声惨嚎，鲜血飞溅而出。\n",
            bindings
          )
        )

      Performs.feedback(attacker, 150, 2)
      put_character(conn, character)
    else
      # LPC: me->start_busy(3); me->add("neili", -60);
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "可是$p并不慌乱，收敛心神，轻轻格挡开了$P的剑招。\n",
            bindings
          )
        )

      Performs.feedback(attacker, 60, 3)
      conn
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "raozhi-roujian/chuan",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define CHUAN "「" HIM "柔月穿空" NOR "」"
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         int ap, dp, damage;
  #         string wn, msg;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/raozhi-roujian/chuankong"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(CHUAN "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" CHUAN "。\n");
  # 
  #         if (me->query_skill("force") < 150)
  #                 return notify_fail("你的内功的修为不够，难以施展" CHUAN "。\n");
  # 
  #         if (me->query_skill("raozhi-roujian", 1) < 100)
  #                 return notify_fail("你的绕指柔剑修为不够，难以施展" CHUAN "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "raozhi-roujian")
  #                 return notify_fail("你没有激发绕指柔剑，难以施展" CHUAN "。\n");
  # 
  #         if (me->query("neili") < 250)
  #                 return notify_fail("你现在真气不够，难以施展" CHUAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         wn = weapon->name();
  # 
  #         message_sort(HIM "\n只见$N" HIM "暮地里一声清啸，剑法忽变，那"
  #                      "柄" + wn + HIM "竟似成了一条软带，轻柔曲折，飘忽"
  #                      "不定，疾刺$n" HIM "胸膛，剑到中途，剑尖微颤，竟"
  #                      "然弯了过去斜刺$n" HIM "右肩，招式精奇之极。\n" NOR,
  #                      me, target);
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 2 + random(ap);
  #                 msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 30,
  #                                           HIR "结果$p一个不慎，登被$P剑招刺中，"
  #                                           "一声惨嚎，鲜血飞溅而出。\n" NOR);
  #                 me->start_busy(2);
  #                 me->add("neili", -150);
  #         } else
  #         {
  #                 msg = CYN "可是$p并不慌乱，收敛心神，轻轻格"
  #                       "挡开了$P的剑招。\n" NOR;
  #                 me->start_busy(3);
  #                 me->add("neili", -60);
  #         }
  #         message_vision(msg, me, target);
  # 
  #         return 1;
  # }
end
