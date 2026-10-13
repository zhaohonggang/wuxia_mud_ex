defmodule Kantele.Combat.Skills.Performs.JinyuanGun.Qian do
  @moduledoc """
  perform「乾坤一击」（source jinyuan-gun/qian.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 手持 club 类武器 →
  内功>=180 → 金猿棍法>=120 → 真气>=200 → 激发 club 为金猿棍法 → 目标存活。
  （`.c` 有 `can_perform`，故设「已知此招」检查。）
  起手广播（含武器名）后按 `ap/2 + random(ap) > 目标 dodge` 判定命中
  （ap = club = 金猿棍法等级）：命中 `damage = ap/2 + random(ap*2/3)`、qi 伤 + 35% 外伤，
  攻击方扣 150 真气 / 忙乱 2；未命中攻击方扣 100 真气 / 忙乱 3。

  差异（TODO(migrate)）：
  - 命中判定与伤害需目标 `dodge`，在目标侧结算；攻击方 `club` 等级经事件 data 传入
    （perform_list 指向本模块，真实实现）；
  - 起手式把武器名插在中文串中间（变量分隔）→ 列表 + Enum.join("") 拆两段；
    命中/未命中广播仅由颜色宏分隔 → 单字面量；
  - 攻击方消耗/忙乱随分支不同，经 `Performs.feedback/3` 回传（起手侧不扣）。
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
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Performs

  @perform_id "jinyuan-gun/qian"
  @move_name "「乾坤一击」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jinyuan-gun")
    ap = Stats.skill(stats, "club")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
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

  # LPC: if (userp(me) && ! me->query("can_perform/jinyuan-gun/qian"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  #          return notify_fail(QIAN "只能对战斗中的对手使用。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon"))
  #          || (string)weapon->query("skill_type") != "club")
  #          return notify_fail("你使用的武器不对，难以施展" QIAN "。\n");
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon != nil and Map.get(weapon, :skill_type) == "club" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 180)
  #          return notify_fail("你的内功的修为不够，难以施展" QIAN "。\n");
  #      if ((int)me->query_skill("jinyuan-gun", 1) < 120)
  #          return notify_fail("你的金猿棍法修为不够，难以施展" QIAN "。\n");
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 180 ->
        {:error, "你的内功的修为不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "jinyuan-gun") < 120 ->
        {:error, "你的金猿棍法修为不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("neili") < 200)
  #          return notify_fail("你的真气不够，难以施展" QIAN "。\n");
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("club") != "jinyuan-gun")
  #          return notify_fail("你没有激发金猿棍法，难以施展" QIAN "。\n");
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "club") == "jinyuan-gun" do
      :ok
    else
      {:error, "你没有激发金猿棍法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (! living(target))
  #          return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: msg = HIY "$N" HIY "大步上前，怒吼一声，手中" + weapon->name() +
  #          HIY "急速舞动，霎时间飞沙走石，罡气激荡。\n便在狂沙飓风中"
  #          "$N" HIY "忽然高高跃起，迎头一棒朝$n" HIY "劈落！\n" NOR;
  defp apply_effect(conn, character, target) do
    weapon_name = Map.get(Combat.weapon(character.meta.combat) || %{}, :name, "")

    msg =
      ["大步上前，怒吼一声，手中", weapon_name,
       "急速舞动，霎时间飞沙走石，罡气激荡。\n便在狂沙飓风中，$N忽然高高跃起，迎头一棒朝$n劈落！\n"]
      |> Enum.join("")

    conn
    |> Broadcast.publish(Messages.interpolate(msg, [n1: character.name, n2: target.name]))
    |> put_character(character)
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
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("dodge");
    #      if (ap / 2 + random(ap) > dp)
    dp = Stats.skill(stats, "dodge")

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap / 2 + random(ap * 2 / 3);
      #      me->add("neili", -150); me->start_busy(2);
      #      do_damage(me, target, WEAPON_ATTACK, damage, 35, (: final, ... :));
      damage = div(ap, 2) + Engine.rand(rng, max(div(ap * 2, 3), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 35, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 150, 2)

      # LPC final: "$n浑身被劲风笼罩，登感窒息，“哇”的吐出一口鲜血，仰面便倒！\n"
      #           （「哇」两侧为全角弯引号 U+201C/201D，非字符串定界符，须照写）
      msg = "$n浑身被劲风笼罩，登感窒息，“哇”的吐出一口鲜血，仰面便倒！\n"

      conn
      |> Broadcast.publish(Messages.interpolate(msg, bindings))
      |> put_character(character)
    else
      # LPC: me->add("neili", -100); me->start_busy(3);
      #      msg += "$n不敢有丝毫大意，急忙纵身后跃，躲开这足以断金裂石的一击。\n";
      Performs.feedback(attacker, 100, 3)

      msg = "$n不敢有丝毫大意，急忙纵身后跃，躲开这足以断金裂石的一击。\n"

      conn
      |> Broadcast.publish(Messages.interpolate(msg, bindings))
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define QIAN "「" HIY "乾坤一击" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/jinyuan-gun/qian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(QIAN "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "club")
  #                 return notify_fail("你使用的武器不对，难以施展" QIAN "。\n");
  # 
  #         if (me->query_skill("force") < 180)
  #                 return notify_fail("你的内功的修为不够，难以施展" QIAN "。\n");
  # 
  #         if (me->query_skill("jinyuan-gun", 1) < 120)
  #                 return notify_fail("你的金猿棍法修为不够，难以施展" QIAN "。\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你的真气不够，难以施展" QIAN "。\n");
  # 
  #         if (me->query_skill_mapped("club") != "jinyuan-gun")
  #                 return notify_fail("你没有激发金猿棍法，难以施展" QIAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "大步上前，怒吼一声，手中" + weapon->name() +
  #               HIY "急速舞动，霎时间飞沙走石，罡气激荡。\n便在狂沙飓风中"
  #               "，$N" HIY "忽然高高跃起，迎头一棒朝$n" HIY "劈落！\n" NOR;
  # 
  #         ap = me->query_skill("club");
  #         dp = target->query_skill("dodge");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 2 + random(ap * 2 / 3);
  #                 me->add("neili", -150);
  #                 me->start_busy(2);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 35,
  #                                            HIR "$n" HIR "浑身被劲风笼罩，登感窒息"
  #                                            "，“哇”的吐出一口鲜血，仰面便倒！\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -100);
  #                 me->start_busy(3);
  #                 msg += CYN "$n" CYN "不敢有丝毫大意，急忙纵身后跃，躲"
  #                        "开这足以断金裂石的一击。\n"NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
