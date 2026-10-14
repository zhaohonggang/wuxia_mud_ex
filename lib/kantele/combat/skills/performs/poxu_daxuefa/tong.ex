defmodule Kantele.Combat.Skills.Performs.PoxuDaxuefa.Tong do
  @moduledoc """
  perform「破元通虚」（对照 `kungfu/skill/poxu-daxuefa/tong.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 破虚打穴法>=120 →
  武器为 dagger 或无武器 → 持械时激发 dagger 为破虚打穴法、空手时准备
  finger 为破虚打穴法 → 真气>=200 → 目标存活 → **目标真气未受阻滞**。
  起手文案带 `wp`（持械为 `"手中" + weapon->name()`，空手为
  `finger_name[random(6)]` 六指之一）；随后由目标侧判定
  `ap/2 + random(ap) > 目标内功`（`ap = 破虚打穴法`）：
  命中则 `damage = ap + random(ap)`、外伤比例 50（`do_damage(REMOTE_ATTACK, …)`）、
  攻击方扣 100 真气并忙乱 3，且目标真气受阻（`no_exert`，
  `10 + random(ap/25)` 秒后恢复）；否则攻击方扣 50 真气并忙乱 4。

  差异（TODO(migrate)）：
  - 「目标真气受阻滞」门槛（`target->query_temp("no_exert")`）在攻击方不可得，
    故移到目标侧 `resolve_incoming` 判定，以 `Combat.buff_active?/2` 检查本招
    造成的 buff 为代理（LPC 的 `no_exert` 是共享 temp）；
  - `.c` 的 `final()` 回调返回命中文案并置 `no_exert`，折算为目标侧先广播该
    文案，再用 `Combat.Buff` + `combat/buff-expire` 定时恢复（`applies` 为
    空映射，恢复走 `message` 通道，拼接 `message_combatd` 与 `tell_object`
    两条文案，同 `cuixin_zhang/cui.ex` / `pixie_jian/po.ex`）；
  - `.c` 选目标时先 `clean_up_enemy()` 再 `select_opponent()`；框架侧由
    `combat.enemies` 直接提供当前对手，无对应清理动作（信息性差异）；
  - `finger_name` 全局数组的六个指名字面量与 `"手中"` 前缀按 `.c` 原样保留；
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
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "poxu-daxuefa/tong"
  @move_name "「破元通虚」"

  # LPC: string *finger_name = ({ "左手中指", "左手无名指", "左手食指",
  #                              "右手中指", "右手无名指", "右手食指", });
  @finger_names [
    "左手中指",
    "左手无名指",
    "左手食指",
    "右手中指",
    "右手无名指",
    "右手食指"
  ]

  # LPC: target->set_temp("no_exert", 1) + call_out("poqi_end", 10 + random(ap / 25), ...)
  @no_exert_key "poxu-daxuefa/tong"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: ap = me->query_skill("poxu-daxuefa", 1);
    ap = Stats.skill(stats, "poxu-daxuefa")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_weapon(combat),
         :ok <- check_mapped(character, combat),
         :ok <- check_prepared(character, combat),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
          rng: rng
        }
      })

      apply_effect(conn, character, target, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/poxu-daxuefa/tong"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: me->clean_up_enemy(); if (! target) target = me->select_opponent();
  #      if (! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: skill = me->query_skill("poxu-daxuefa", 1);
  #      if (skill < 120)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "poxu-daxuefa") < 120 do
      {:error, "你破虚打穴法等级不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: weapon = me->query_temp("weapon");
  #      if (weapon && weapon->query("skill_type") != "dagger")
  defp check_weapon(combat) do
    case Combat.weapon(combat) do
      nil ->
        :ok

      weapon ->
        if Map.get(weapon, :skill_type) == "dagger" do
          :ok
        else
          {:error, "你所使用的武器不对，无法施展#{@move_name}。\n"}
        end
    end
  end

  # LPC: if (weapon && me->query_skill_mapped("dagger") != "poxu-daxuefa")
  defp check_mapped(character, combat) do
    if Combat.weapon(combat) == nil or
         Stats.mapped(character.meta.stats, "dagger") == "poxu-daxuefa" do
      :ok
    else
      {:error, "你没有激发破虚打穴法，无法施展#{@move_name}。\n"}
    end
  end

  # LPC: if (! weapon && me->query_skill_prepared("finger") != "poxu-daxuefa")
  defp check_prepared(character, combat) do
    weapon = Combat.weapon(combat)
    prepared = Stats.prepared_perform(character.meta.stats, "finger")

    if weapon != nil or (prepared != nil and hd(String.split(prepared, "/")) == "poxu-daxuefa") do
      :ok
    else
      {:error, "你没有准备破虚打穴法，无法施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query("neili") < 200)
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不够，无法施展#{@move_name}。\n"}
    else
      :ok
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

  # LPC: if (weapon) wp = "手中" + weapon->name();
  #      else wp = finger_name[random(sizeof(finger_name))];
  #      msg = HIG "$N" HIG "翻转" + wp + HIG "，接连变化数种打穴手法，一式「"
  #            HIR "破元通虚" HIG "」直捣$n" HIG "胸前要穴。\n" NOR;
  #      之后按分支扣 neili / start_busy / do_damage（在目标侧结算）。
  defp apply_effect(conn, character, target, rng) do
    weapon = Combat.weapon(character.meta.combat)

    wp =
      if weapon != nil do
        "手中" <> weapon_name(character.meta.combat)
      else
        Enum.at(@finger_names, Engine.rand(rng, length(@finger_names)))
      end

    Broadcast.publish(
      conn,
      "$N翻转" <> wp <> "，接连变化数种打穴手法，一式「破元通虚」直捣$n胸前要穴。\n",
      n1: character.name,
      n2: target.name
    )
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  # LPC: if (target->query_temp("no_exert"))
  #      return notify_fail("对方现在已经无法控制真气，放胆攻击吧。\n");
  # 目标真气阻滞状态只在目标侧可见，故与死亡检查一并在此结算。
  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    cond do
      character.meta.combat.dead ->
        conn

      Combat.buff_active?(character.meta.combat, @no_exert_key) ->
        Broadcast.publish(conn, "对方现在已经无法控制真气，放胆攻击吧。\n")

      true ->
        do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force", 1);
    dp = Stats.skill(character.meta.stats, "force")

    # LPC: if (ap / 2 + random(ap) > dp)
    #      { damage = ap + random(ap);
    #        msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 50,
    #                                   (: final, me, target, damage :));
    #        me->add("neili", -100);
    #        me->start_busy(3); }
    #      else
    #      { msg += CYN "可是$n" CYN "早已看破$N"
    #                     CYN "招中虚实，单手一挥，登将这招化于无形。\n" NOR;
    #        me->add("neili", -50);
    #        me->start_busy(4); }
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      damage = ap + Engine.rand(rng, ap)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 50, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: me->add("neili", -100);  me->start_busy(3);
      Performs.feedback(attacker, 100, 3)

      # LPC final(): target->set_temp("no_exert", 1);
      #              call_out("poqi_end", 10 + random(ap / 25), me, target);
      #              return HIR "$n" HIR "只觉胸口一麻，已被$N" HIR "点中"
      #                     "要穴，登时全身真气阻滞，苦不堪言！\n" NOR;
      no_exert_duration = 10 + Engine.rand(rng, div(ap, 25))

      combat =
        character.meta.combat
        |> Combat.add_buff(%Combat.Buff{
          key: @no_exert_key,
          applies: %{},
          duration: no_exert_duration
        })

      character = %{character | meta: %{character.meta | combat: combat}}

      # LPC poqi_end(): message_combatd(HIC "$N" HIC "深深吸入一口气，脸色由"
      #                                 "白转红，看起来好多了。\n" NOR, target);
      #                  tell_object(target, HIY "你感到被扰乱的真气慢慢平静"
      #                                      "了下来。\n" NOR);
      #                  target->delete_temp("no_exert");
      Process.send_after(
        self(),
        %Event{
          from_pid: self(),
          topic: "combat/buff-expire",
          data: %{
            key: @no_exert_key,
            applies: %{},
            message:
              [
                Messages.interpolate("$N深深吸入一口气，脸色由白转红，看起来好多了。\n",
                  n1: character.name
                ),
                "你感到被扰乱的真气慢慢平静了下来。\n"
              ]
              |> Enum.join("")
          }
        },
        no_exert_duration * 1000
      )

      conn
      |> Broadcast.publish(
        "$n只觉胸口一麻，已被$N点中要穴，登时全身真气阻滞，苦不堪言！\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: me->add("neili", -50);  me->start_busy(4);
      Performs.feedback(attacker, 50, 4)

      conn
      |> Broadcast.publish(
        "可是$n早已看破$N招中虚实，单手一挥，登将这招化于无形。\n",
        bindings
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define TONG "「" HIR "破元通虚" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string final(object me, object target, int damage);
  # 
  # string *finger_name = ({ "左手中指", "左手无名指", "左手食指",
  #                          "右手中指", "右手无名指", "右手食指", }); 
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string wp, msg;
  #         int ap, dp, skill;
  #         int damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/poxu-daxuefa/tong"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         me->clean_up_enemy();
  #         if (! target) target = me->select_opponent();
  # 
  #         skill = me->query_skill("poxu-daxuefa", 1);
  # 
  #         if (! me->is_fighting(target))
  #                 return notify_fail(TONG "只能对战斗中的对手使用。\n");
  # 
  #         if (skill < 120)
  #                 return notify_fail("你破虚打穴法等级不够，无法施展" TONG "。\n");
  # 
  #         weapon = me->query_temp("weapon");
  # 
  #         if (weapon && weapon->query("skill_type") != "dagger")
  #                 return notify_fail("你所使用的武器不对，无法施展" TONG "。\n");
  # 
  #         if (weapon && me->query_skill_mapped("dagger") != "poxu-daxuefa")
  #                 return notify_fail("你没有激发破虚打穴法，无法施展" TONG "。\n");
  # 
  #         if (! weapon && me->query_skill_prepared("finger") != "poxu-daxuefa")
  #                 return notify_fail("你没有准备破虚打穴法，无法施展" TONG "。\n");
  # 
  #         if (target->query_temp("no_exert"))
  #                 return notify_fail("对方现在已经无法控制真气，放胆攻击吧。\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够，无法施展" TONG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         if (weapon)
  #                 wp = "手中" + weapon->name();
  #         else
  #                 wp = finger_name[random(sizeof(finger_name))];
  # 
  #         msg = HIG "$N" HIG "翻转" + wp + HIG "，接连变化数种打穴手法，一式「"
  #               HIR "破元通虚" HIG "」直捣$n" HIG "胸前要穴。\n" NOR;
  # 
  #         ap = me->query_skill("poxu-daxuefa", 1);
  #         dp = target->query_skill("force", 1);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap);
  #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 50,
  #                                            (: final, me, target, damage :));
  #                 me->add("neili", -100);
  #                 me->start_busy(3);
  #         } else
  #         {
  #                 msg += CYN "可是$n" CYN "早已看破$N"
  #                        CYN "招中虚实，单手一挥，登将这招化于无形。\n" NOR;
  #                 me->add("neili", -50);
  #                 me->start_busy(4);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
  # 
  # string final(object me, object target, int ap)
  # {
  #         target->set_temp("no_exert", 1);
  #         call_out("poqi_end", 10 + random(ap / 25), me, target);
  #         return  HIR "$n" HIR "只觉胸口一麻，已被$N" HIR "点中"
  #                 "要穴，登时全身真气阻滞，苦不堪言！\n" NOR;
  # }
  # 
  # void poqi_end(object me, object target)
  # {
  #         if (target && living(target) && target->query_temp("no_exert"))
  #         {
  #                 message_combatd(HIC "$N" HIC "深深吸入一口气，脸色由"
  #                                 "白转红，看起来好多了。\n" NOR, target);
  # 
  #                 target->delete_temp("no_exert");
  #                 tell_object(target, HIY "你感到被扰乱的真气慢慢平静"
  #                                     "了下来。\n" NOR);
  #         }
  #         return;
  # }
end
