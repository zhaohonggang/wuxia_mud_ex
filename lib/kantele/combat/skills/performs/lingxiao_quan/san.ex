defmodule Kantele.Combat.Skills.Performs.LingxiaoQuan.San do
  @moduledoc """
  perform「神倒鬼跌三连环」（source lingxiao-quan/san.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 空手 → 内功>=250 →
  凌霄拳法>=180 → 真气>=300 → 激发 cuff 为凌霄拳法 → 准备凌霄拳法 → 目标存活。
  三环依次「揪后颈 / 抓前胸 / 扫下盘」，各环独立命中判定
  `cuff/2 + random(cuff)` > 目标 `parry` / `dodge` / `force`；
  伤害 `凌霄拳法/2 + random(同值)`（三环共用，攻击方摇定），do_damage 外伤
  比例依次 20/25/30；收招扣 200 真气、忙乱 `2+random(3)`。

  差异（TODO(migrate)）：
  - LPC 把三环文案串进单个 msg 后一次 message_combatd；E 侧三环在目标侧
    依次结算，每环先发自己的起手式再发命中/化解文案（三环顺序保持）；
  - damage 的 random 在攻击方摇定后经事件数据传目标侧（三环共用同一值）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Performs

  @perform_id "lingxiao-quan/san"
  @move_name "「神倒鬼跌三连环」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "lingxiao-quan")
    ap = Stats.skill(stats, "cuff")
    # LPC: damage = lingxiao-quan / 2; damage += random(damage);
    damage = div(lvl, 2) + Engine.rand(rng, div(lvl, 2))

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
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
          damage: damage,
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

  # LPC: if (userp(me) && ! me->query("can_perform/lingxiao-quan/san"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (objectp(weapon = me->query_temp("weapon")))
  defp check_weapon(combat) do
    if Combat.weapon(combat) == nil do
      :ok
    else
      {:error, "只有空手才能施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 250)
  #         if ((int)me->query_skill("lingxiao-quan", 1) < 180)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 250 ->
        {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "lingxiao-quan") < 180 ->
        {:error, "你的凌霄拳法不够娴熟，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 300)
  defp check_resources(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("cuff") != "lingxiao-quan")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "cuff") == "lingxiao-quan" do
      :ok
    else
      {:error, "你没有激发凌霄拳法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("cuff") != "lingxiao-quan")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "cuff")

    if prepared == nil or hd(String.split(prepared, "/")) != "lingxiao-quan" do
      {:error, "你现在没有准备使用凌霄拳法，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC 三环文案全部在目标侧随结算发出（攻击方无额外前置效果）。
  defp apply_effect(conn, _character, _target) do
    conn
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
    damage = Map.get(data, :damage, 0)
    stats = character.meta.stats

    # 第一环揪后颈：ap/2 + random(ap) vs parry，do_damage 外伤比例 20
    {conn, character} = resolve_ring(conn, character, attacker, rng, %{
      lead: "$N微微一笑，施出「神倒鬼跌三连环」，右手探出，直揪$n后颈。\n",
      hit_msg: "$P出手既快，方位又奇，$p如何避得，当即被$N揪住，重重的摔在地上！\n",
      miss_msg: "$p见势不妙，急忙凝力稳住，右臂挥出，格开$P手臂。\n",
      ap: ap, dp: Stats.skill(stats, "parry"), damage: damage, percent: 20
    })

    # 第二环抓前胸：ap/2 + random(ap) vs dodge，do_damage 外伤比例 25
    {conn, character} = resolve_ring(conn, character, attacker, rng, %{
      lead: "\n紧接着$N“噫”的一声，左手猛然探出，如闪电般抓向$n的前胸。\n",
      hit_msg: "$p只觉胸口一麻，已被$P抓住胸口，用力顺势一甩，顿时平平飞了出去！\n",
      miss_msg: "可是$p丝毫不为$P所动，奋力格挡，稳稳将这一招架开。\n",
      ap: ap, dp: Stats.skill(stats, "dodge"), damage: damage, percent: 25
    })

    # 第三环扫下盘：ap/2 + random(ap) vs force，do_damage 外伤比例 30
    {conn, _character} = resolve_ring(conn, character, attacker, rng, %{
      lead: "\n又见$N身子一矮，将力道聚于腿部，右脚猛扫$n下盘，左脚随着绊去。\n",
      hit_msg: "结果$p稍不留神，顿时给$P绊倒在地，呕出一大口鲜血！\n",
      miss_msg: "然而$p沉身聚气，稳住下盘，身子一幌，没给$P绊倒。\n",
      ap: ap, dp: Stats.skill(stats, "force"), damage: damage, percent: 30
    })

    # LPC: me->start_busy(2 + random(3)); me->add("neili", -200);
    Performs.feedback(attacker, 200, 2 + Engine.rand(rng, 3))

    conn
  end

  # 单环结算：命中走 do_damage(UNARMED_ATTACK, damage, percent)，未命中走化解文案。
  # 返回更新后的 conn 与 character，供下一环继续累加伤害。
  defp resolve_ring(conn, character, attacker, rng, opts) do
    ap = max(Map.get(opts, :ap, 0), 1)
    dp = Map.get(opts, :dp, 0)
    hit? = div(ap, 2) + Engine.rand(rng, ap) > dp

    {vitals, msg} =
      if hit? do
        damage = Map.get(opts, :damage, 0)
        percent = Map.get(opts, :percent, 0)
        v = character.meta.vitals
            |> Vitals.damage(:qi, damage)
            |> Vitals.wound(:qi, div(damage * percent, 100))
        {v, Map.get(opts, :hit_msg)}
      else
        {character.meta.vitals, Map.get(opts, :miss_msg)}
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn =
      conn
      |> Broadcast.publish(Map.get(opts, :lead), n1: attacker.name, n2: character.name)
      |> Broadcast.publish(msg, n1: attacker.name, n2: character.name)

    {conn, character}
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define SAN "「" HIR "神倒鬼跌三连环" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         object weapon;
  # //      string wname;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/lingxiao-quan/san"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(SAN "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(weapon = me->query_temp("weapon")))
  #                 return notify_fail("只有空手才能施展" SAN "。\n");
  # 
  #         if (me->query_skill("force") < 250)
  #                 return notify_fail("你的内功修为不够，难以施展" SAN "。\n");
  # 
  #         if ((int)me->query_skill("lingxiao-quan", 1) < 180)
  #                 return notify_fail("你的凌霄拳法不够娴熟，难以施展" SAN "。\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #                 return notify_fail("你现在真气不够，难以施展" SAN "。\n");
  # 
  #         if (me->query_skill_mapped("cuff") != "lingxiao-quan")
  #                 return notify_fail("你没有激发凌霄拳法，难以施展" SAN "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "lingxiao-quan")
  #                 return notify_fail("你现在没有准备使用凌霄拳法，难以施展" SAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         damage = (int)me->query_skill("lingxiao-quan", 1) / 2;
  #         damage += random(damage);
  # 
  #         ap = me->query_skill("cuff");
  #         dp = target->query_skill("parry");
  #         msg = HIR "$N" HIR "微微一笑，施出「神倒鬼跌三连环」，右手探出，直揪$n"
  #               HIR "后颈。\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
  #                                            HIR "$P" HIR "出手既快，方位又奇，$p"
  #                                            HIR "如何避得，当即被$N" HIR "揪住，"
  #                                            "重重的摔在地上！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "见势不妙，急忙凝力稳住，右臂挥出，格开$P"
  #                        CYN "手臂。\n" NOR;
  #         }
  # 
  #         ap = me->query_skill("cuff");
  #         dp = target->query_skill("dodge");
  #         msg += "\n" HIR "紧接着$N" HIR "“噫”的一声，左手猛然探出，如闪电般抓向$n"
  #                HIR "的前胸。\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 25,
  #                                            HIR "$p" HIR "只觉胸口一麻，已被$P"
  #                                            HIR "抓住胸口，用力顺势一甩，顿时平"
  #                                            "平飞了出去！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "丝毫不为$P"
  #                        CYN "所动，奋力格挡，稳稳将这一招架开。\n" NOR;
  #         }
  # 
  #         ap = me->query_skill("cuff");
  #         dp = target->query_skill("force");
  #         msg += "\n" HIR "又见$N" HIR "身子一矮，将力道聚于腿部，右脚猛扫$n"
  #                HIR "下盘，左脚随着绊去。\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
  #                                            HIR "结果$p" HIR "稍不留神，顿时给$P"
  #                                            HIR "绊倒在地，呕出一大口鲜血！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "然而$p" CYN "沉身聚气，稳住下盘，身子一幌，没给$P"
  #                        CYN "绊倒。\n" NOR;
  #         }
  #         me->start_busy(2 + random(3));
  #         me->add("neili", -200);
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
