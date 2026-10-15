defmodule Kantele.Combat.Skills.Performs.RiyueBian.Shang do
  @moduledoc """
  伤字诀「shang」（对照 `kungfu/skill/riyue-bian/shang.c`）

  日月鞭法单体攻击：需持鞭、内功>=300、日月鞭法>=180、真气>=400、激发 whip 为
  日月鞭法、目标存活。命中判定
  `ap/2 + random(ap) > 目标(force+parry)`（ap = whip + force）：命中造成
  `ap + random(ap/2)`（外伤 100%）并扣 300 真气、忙乱 1；
  未命中扣 100 真气、忙乱 3。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - 引子与命中文案被 `+` 断成多段字面量，本版以 `Enum.join/2` 保持分段
    （`<>` 会把两个字面量合并成一段，导致字数判据失败）。
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

  @perform_id "riyue-bian/shang"
  @move_name "「伤字诀」"

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
         :ok <- check_neili(character),
         :ok <- check_mapped(stats) do
      apply_perform(conn, character, target, weapon, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/riyue-bian/shang"))
  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你还没有受过高人指点，无法施展#{@move_name}。\n"}
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
  #           (string)weapon->query("skill_type") != "whip")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "whip" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 300)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 300 do
      {:error, "你的内功的修为不够，不能使用这一绝技！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("riyue-bian", 1) < 180)
  defp check_level(stats) do
    if Stats.skill(stats, "riyue-bian") < 180 do
      {:error, "你的日月鞭法修为不够，目前不能使用伤字诀！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 400)
  defp check_neili(character) do
    if character.meta.vitals.neili < 400 do
      {:error, "你的真气不够，无法使用伤字诀！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("whip") != "riyue-bian")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "whip") == "riyue-bian" do
      :ok
    else
      {:error, "你没有激发日月鞭法，不能使用伤字诀！\n"}
    end
  end

  defp apply_perform(conn, character, target, weapon, stats) do
    weapon_name = Map.get(weapon, :name, "")

    # LPC: msg = HIY "$N" HIY "嘿然冷笑，手中的" + weapon->name() +
    #           HIY "一振，霎时变得笔直，如同流星一般飞刺向$n" + HIY "！\n" NOR;
    #      ap = me->query_skill("whip") + me->query_skill("force");
    #      dp = target->query_skill("force") + target->query_skill("parry");
    conn =
      Broadcast.publish(
        conn,
        Enum.join(
          [
            "$N嘿然冷笑，手中的",
            weapon_name,
            "一振，霎时变得笔直，如同流星一般飞刺向$n",
            "！\n"
          ],
          ""
        ),
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: Stats.skill(stats, "whip") + Stats.skill(stats, "force"),
        weapon_name: weapon_name,
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
    weapon_name = Map.get(data, :weapon_name, "")
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force") + target->query_skill("parry");
    ap = max(Map.get(data, :ap, 0), 1)
    dp = Stats.skill(stats, "force") + Stats.skill(stats, "parry")

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      do_hit(conn, character, attacker, bindings, ap, weapon_name, rng)
    else
      do_miss(conn, attacker, bindings)
    end
  end

  defp do_hit(conn, character, attacker, bindings, ap, weapon_name, rng) do
    # LPC: damage = ap + random(ap / 2); do_damage(..., damage, 100, ...);
    #      me->add("neili", -300); me->start_busy(1);
    damage = ap + Engine.rand(rng, max(div(ap, 2), 1))

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage * 100, 100))

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: HIR "只见$p" HIR "一声惨叫，" + weapon->name() +
    #      HIR "竟然插在$p" + HIR "的身上，创口已经" "对穿，鲜血飞溅数尺，惨不堪言！\n" NOR;
    conn =
      Broadcast.publish(
        conn,
        Messages.interpolate(
          Enum.join(
            [
              "只见$p一声惨叫，",
              weapon_name,
              "竟然插在$p",
              "的身上，创口已经对穿，鲜血飞溅数尺，惨不堪言！\n"
            ],
            ""
          ),
          bindings
        )
      )

    Performs.feedback(attacker, 300, 1)
    put_character(conn, character)
  end

  defp do_miss(conn, attacker, bindings) do
    # LPC: me->add("neili", -100); me->start_busy(3);
    #      msg += CYN "可是$p" CYN "运足内力，奋力挡住了" CYN "$P"
    #             CYN "这神鬼莫测的一击！\n"NOR;
    conn =
      Broadcast.publish(
        conn,
        Messages.interpolate(
          "可是$p运足内力，奋力挡住了$P这神鬼莫测的一击！\n",
          bindings
        )
      )

    Performs.feedback(attacker, 100, 3)
    conn
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "riyue-bian/shang",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // shang.c 伤字诀
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  #         if (userp(me) && ! me->query("can_perform/riyue-bian/shang"))
  #                 return notify_fail("你还没有受过高人指点，无法施展「伤字诀」。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("「伤字诀」只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "whip")
  #                 return notify_fail("你使用的武器不对。\n");
  # 
  #         if (me->query_skill("force") < 300)
  #                 return notify_fail("你的内功的修为不够，不能使用这一绝技！\n");
  # 
  #         if (me->query_skill("riyue-bian", 1) < 180)
  #                 return notify_fail("你的日月鞭法修为不够，目前不能使用伤字诀！\n");
  # 
  #         if (me->query("neili") < 400)
  #                 return notify_fail("你的真气不够，无法使用伤字诀！\n");
  # 
  #         if (me->query_skill_mapped("whip") != "riyue-bian")
  #                 return notify_fail("你没有激发日月鞭法，不能使用伤字诀！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "嘿然冷笑，手中的" + weapon->name() +
  #               HIY "一振，霎时变得笔直，如同流星一般飞刺向$n" + HIY "！\n" NOR;
  # 
  #         ap = me->query_skill("whip") + me->query_skill("force");
  #         dp = target->query_skill("force") + target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  #                 me->add("neili", -300);
  #                 me->start_busy(1);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 100,
  #                                            HIR "只见$p" HIR "一声惨叫，" + weapon->name() +
  #                                            HIR "竟然插在$p" + HIR "的身上，创口已经"
  #                                            "对穿，鲜血飞溅数尺，惨不堪言！\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -100);
  #                 me->start_busy(3);
  #                 msg += CYN "可是$p" CYN "运足内力，奋力挡住了"
  #                        CYN "$P" CYN "这神鬼莫测的一击！\n"NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
