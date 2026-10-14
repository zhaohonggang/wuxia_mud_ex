defmodule Kantele.Combat.Skills.Performs.MurongJian.Xing do
  @moduledoc """
  perform「剑转七星」（对照 `kungfu/skill/murong-jian/xing.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 手持 sword 类武器 →
  慕容剑法>=80 → 激发 `sword` 为慕容剑法 → 轻功>=120 → 真气>=200 → 目标存活。
  起手文案（含武器名 `weapon->name()`）在攻击方广播；攻击方无条件扣 210 真气、
  忙乱 `3 + random(5)`。目标侧连续 7 击（每击前若目标不忙乱且 `random(2)==1`
  则先给目标忙乱 1），每击按 `慕容剑法/2 + random(慕容剑法)` 对目标 `dodge`
  判定命中，命中累加 qi 伤害（qi 上限伤为累计值/3）。

  差异（TODO(migrate)）：
  - `.c` 用 `message_vision(msg, me, target)` 广播起手；7 击为
    `COMBAT_D->do_attack(me, target, weapon, 13)`（第 4 参为 attack_type、无独立文案），
    本引擎无 per-skill `do_attack` 钩子，折算为目标侧逐击命中判定 + 累加 qi 伤害
    （同 `luohan_jian/wuxing.ex`）；
  - 循环中的 `if (! me->is_fighting(target)) break;` 折算为目标侧
    `Combat.enemy?(combat, attacker.id)` 判定（`Enum.reduce` 无法 break，以不再累加近似）；
  - `me->add("neili",-210)` 与收尾的 `me->start_busy(3+random(5))` 无条件 →
    在攻击方直接结算（忙乱与 7 击的相对次序为跨进程近似）；
  - `!living(target)` 门槛在攻击方无 meta 可查，恒判存活，由目标侧
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

  @perform_id "murong-jian/xing"
  @move_name "「剑转七星」"
  @strikes 7

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "murong-jian")
    wn = weapon_name(combat)

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_dodge(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          strikes: @strikes,
          rng: rng
        }
      })

      apply_effect(conn, character, target, wn, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/murong-jian/xing"))
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

  # LPC: if (! objectp(weapon = me->query_temp("weapon"))
  #          || (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("murong-jian", 1) < 80)
  defp check_level(stats) do
    if Stats.skill(stats, "murong-jian") < 80 do
      {:error, "你的慕容剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "murong-jian")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") != "murong-jian" do
      {:error, "你没有激发慕容剑法，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("dodge") < 120)
  defp check_dodge(stats) do
    if Stats.skill(stats, "dodge") < 120 do
      {:error, "你的轻功修为不够，无法施展#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 200)
  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你目前的真气不够，难以施展#{@move_name}。\n"}
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

  defp apply_effect(conn, character, target, wn, rng) do
    # LPC: msg = HIM "$N" HIM "使出慕容家绝技「" HIW "剑转七星" HIM "」，手中"
    #            + weapon->name() + HIM "暗合北斗七星方位，忽伸忽缩，变化莫测！\n" NOR;
    conn =
      Broadcast.publish(
        conn,
        "$N使出慕容家绝技#{@move_name}，手中" <> wn <> "暗合北斗七星方位，忽伸忽缩，变化莫测！\n",
        n1: character.name,
        n2: target.name
      )

    # LPC: me->add("neili", -210);
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 210}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->start_busy(3 + random(5));
    combat = Combat.start_busy(character.meta.combat, 3 + Engine.rand(rng, 5))
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp weapon_name(combat) do
    case Combat.weapon(combat) do
      nil -> nil
      weapon -> Map.get(weapon, :name)
    end
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
    level = max(Map.get(data, :level, 0), 1)
    strikes = Map.get(data, :strikes, @strikes)
    dodge = Stats.skill(character.meta.stats, "dodge")
    per_hit = max(div(level, 15), 1)

    # LPC: for (i = 0; i < 7; i++)
    #      { if (! me->is_fighting(target)) break;
    #        if (! target->is_busy() && random(2) == 1) target->start_busy(1);
    #        COMBAT_D->do_attack(me, target, weapon, 13); }
    # 折算：逐击命中判定（level/2 + random(level) vs 目标 dodge）+ 累加伤害。
    {combat, damage} =
      Enum.reduce(1..strikes, {character.meta.combat, 0}, fn _, {combat, acc} ->
        if Combat.enemy?(combat, attacker.id) do
          combat =
            if not Combat.busy?(combat) and Engine.rand(rng, 2) == 1 do
              Combat.start_busy(combat, 1)
            else
              combat
            end

          acc =
            if div(level, 2) + Engine.rand(rng, level) > dodge do
              acc + per_hit + Engine.rand(rng, per_hit)
            else
              acc
            end

          {combat, acc}
        else
          {combat, acc}
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    put_character(conn, character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHUAN "「" HIW "剑转七星" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #     int i;
  # 
  #         if (userp(me) && ! me->query("can_perform/murong-jian/xing"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHUAN "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你所使用的武器不对，难以施展" ZHUAN "。\n");
  # 
  #     if ((int)me->query_skill("murong-jian", 1) < 80)
  #         return notify_fail("你的慕容剑法不够娴熟，难以施展" ZHUAN "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "murong-jian")
  #                 return notify_fail("你没有激发慕容剑法，难以施展" ZHUAN "。\n");
  # 
  #     if ((int)me->query_skill("dodge") < 120)
  #         return notify_fail("你的轻功修为不够，无法施展" ZHUAN "！\n");
  # 
  #     if (me->query("neili") < 200)
  #         return notify_fail("你目前的真气不够，难以施展" ZHUAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIM "$N" HIM "使出慕容家绝技「" HIW "剑转七星" HIM "」，手中"
  #               + weapon->name() + HIM "暗合北斗七星方位，忽伸忽缩，变化莫测！\n" NOR;
  # 
  #     me->add("neili", -210);
  # 
  #         message_vision(msg, me, target);
  # 
  #         for (i = 0; i < 7; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 if (! target->is_busy() && random(2) == 1)
  #                         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, weapon, 13);
  #         }
  # 
  #     me->start_busy(3 + random(5));
  # 
  #         return 1;
  # }
end
