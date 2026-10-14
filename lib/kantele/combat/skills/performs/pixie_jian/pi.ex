defmodule Kantele.Combat.Skills.Performs.PixieJian.Pi do
  @moduledoc """
  perform「群邪辟易」（对照 `kungfu/skill/pixie-jian/pi.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 武器为 sword/pin 或无武器 →
  辟邪剑法>=120 → 真气>=200 → 持械时激发 sword 为辟邪剑法、空手时准备
  unarmed 为辟邪剑法 → 目标存活。
  起手文案带 `name`（持械为 `"手中" + weapon->name()`，空手为
  `finger_name[random(6)]` 六指之一）；随后由目标侧判定
  `ap/2 + random(ap) > 目标闪避`（`ap = 轻功`）取 `count = ap/4`（命中）或
  `ap/8`（未命中），并连出 9 击，攻击方扣 100 真气、忙乱 `1 + random(7)`。

  差异（TODO(migrate)）：
  - `me->add_temp("apply/attack|apply/damage|apply/unarmed_damage", ±count)`
    三组临时加成折入目标侧逐击（attack 类折入命中判定、damage 类折入每击伤害），
    收招的三个 `-count` 不再重复落账（同 `luoyan_jian/luo.ex`）；
  - `.c` 的 9 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为每击
    `level/15 + count` 基础伤害 + 命中判定（`ap/2 + count + random(ap)` vs
    目标 dodge）；`do_attack` 无独立命中/失手文案，由引擎动作表生成，故本文件
    不再自行发布逐击结果文案；
  - `me->add_temp("pixie-jian/hit_msg", 1)` 只是给 COMBAT_D 的命中文案加标记，
    本仓无对应管道，故不建模（差异记录于此，收招的 `delete_temp` 同理）；
  - `.c` 起手文案以 `name` 变量为界拆为三段字面量，空手指名从
    `finger_name` 全局数组中随机取；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
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

  @perform_id "pixie-jian/pi"
  @move_name "「群邪辟易」"

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

  # LPC: for (i = 0; i < 9; i++) COMBAT_D->do_attack(me, target, weapon, 0);
  @strikes 9

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: ap = me->query_skill("dodge", 1);
    ap = Stats.skill(stats, "dodge")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character, combat),
         :ok <- check_prepared(character, combat),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
          strikes: @strikes,
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

  # LPC: if (userp(me) && ! me->query("can_perform/pixie-jian/pi"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) { me->clean_up_enemy(); target = me->select_opponent(); }
  #      if (! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (weapon && weapon->query("skill_type") != "sword"
  #           && weapon->query("skill_type") != "pin")
  defp check_weapon(combat) do
    case Combat.weapon(combat) do
      nil ->
        :ok

      weapon ->
        if Map.get(weapon, :skill_type) in ["sword", "pin"] do
          :ok
        else
          {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
        end
    end
  end

  # LPC: if (me->query_skill("pixie-jian", 1) < 120)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "pixie-jian") < 120 do
      {:error, "你的辟邪剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 200)
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (weapon && me->query_skill_mapped("sword") != "pixie-jian")
  #              return notify_fail("你没有准备使用辟邪剑法，难以施展" PI "。\n");
  #      （空手时该门槛不生效；文案与下一档相同，.c 中各自出现一次）
  defp check_mapped(character, combat) do
    weapon = Combat.weapon(combat)

    if weapon == nil or Stats.mapped(character.meta.stats, "sword") == "pixie-jian" do
      :ok
    else
      {:error, "你没有准备使用辟邪剑法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (! weapon && me->query_skill_prepared("unarmed") != "pixie-jian")
  #              return notify_fail("你没有准备使用辟邪剑法，难以施展" PI "。\n");
  #      （持械时该门槛不生效）
  defp check_prepared(character, combat) do
    weapon = Combat.weapon(combat)
    prepared = Stats.prepared_perform(character.meta.stats, "unarmed")

    if weapon != nil or (prepared != nil and hd(String.split(prepared, "/")) == "pixie-jian") do
      :ok
    else
      {:error, "你没有准备使用辟邪剑法，难以施展#{@move_name}。\n"}
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

  # LPC: if (me->query_temp("weapon")) name = "手中" + weapon->name();
  #      else name = finger_name[random(sizeof(finger_name))];
  #      msg = HIW "$N" HIW "身形忽然变快，蓦的冲向$n" HIW "，" + name +
  #            HIW "幻作数道虚影，顿时无数星光一齐射向$n" HIW "！\n" NOR;
  #      message_combatd(msg, me, target);
  #      … 9 击（目标侧结算）…
  #      me->add("neili", -100);
  #      me->start_busy(1 + random(7));
  defp apply_effect(conn, character, target, rng) do
    weapon = Combat.weapon(character.meta.combat)

    name =
      if weapon != nil do
        "手中" <> weapon_name(character.meta.combat)
      else
        Enum.at(@finger_names, Engine.rand(rng, length(@finger_names)))
      end

    conn =
      Broadcast.publish(
        conn,
        "$N身形忽然变快，蓦的冲向$n，" <> name <> "幻作数道虚影，顿时无数星光一齐射向$n！\n",
        n1: character.name,
        n2: target.name
      )

    # LPC: me->add("neili", -100);
    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 100, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->start_busy(1 + random(7));
    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 7))
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
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

  defp do_resolve_incoming(conn, character, _attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    strikes = Map.get(data, :strikes, @strikes)
    level = Stats.skill(character.meta.stats, "pixie-jian")
    dodge = Stats.skill(character.meta.stats, "dodge")

    # LPC: dp = target->query_skill("dodge", 1);
    #      if (ap / 2 + random(ap) > dp) count = ap / 4;  else count = ap / 8;
    count =
      if div(ap, 2) + Engine.rand(rng, ap) > dodge do
        div(ap, 4)
      else
        div(ap, 8)
      end

    # LPC: for (i = 0; i < 9; i++) { if (! me->is_fighting(target)) break;
    #            if (random(3) == 0 && ! target->is_busy()) target->start_busy(1);
    #            COMBAT_D->do_attack(me, target, weapon, 0); }
    # 折算：每击 level/15 + count 基础伤害 + 命中判定（ap/2 + count + random(ap) vs dodge）。
    {combat, damage} =
      Enum.reduce(1..strikes, {character.meta.combat, 0}, fn _, {combat_acc, damage_acc} ->
        combat_acc =
          if Engine.rand(rng, 3) == 0 and not Combat.busy?(combat_acc) do
            Combat.start_busy(combat_acc, 1)
          else
            combat_acc
          end

        if div(ap, 2) + count + Engine.rand(rng, ap) > dodge do
          per_hit = max(div(level, 15), 1) + count
          {combat_acc, damage_acc + per_hit + Engine.rand(rng, per_hit)}
        else
          {combat_acc, damage_acc}
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
  # #define PI "「" HIW "群邪辟易" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string *finger_name = ({ "左手中指", "左手无名指", "左手食指",
  #                          "右手中指", "右手无名指", "右手食指", });
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         string name;
  #         object weapon;
  #         int i;
  #         int skill;
  #         int count;
  #         int dp;
  #         int ap;
  # 
  #         if (userp(me) && ! me->query("can_perform/pixie-jian/pi"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! me->is_fighting(target))
  #                 return notify_fail(PI "只能对战斗中的对手使用。\n");
  # 
  #         weapon = me->query_temp("weapon");
  # 
  #         if (weapon && weapon->query("skill_type") != "sword" &&
  #             weapon->query("skill_type") != "pin")
  #                 return notify_fail("你使用的武器不对，难以施展" PI "。\n");
  # 
  #         if (me->query_temp("weapon"))
  #                 name = "手中" + weapon->name();
  #         else
  #                 name = finger_name[random(sizeof(finger_name))];
  # 
  #         skill = me->query_skill("pixie-jian", 1);
  # 
  #         if (skill < 120)
  #                 return notify_fail("你的辟邪剑法不够娴熟，难以施展" PI "。\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不足，难以施展" PI "。\n");
  # 
  #         if (weapon && me->query_skill_mapped("sword") != "pixie-jian")
  #                 return notify_fail("你没有准备使用辟邪剑法，难以施展" PI "。\n");
  # 
  #         if (! weapon && me->query_skill_prepared("unarmed") != "pixie-jian")
  #                 return notify_fail("你没有准备使用辟邪剑法，难以施展" PI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "身形忽然变快，蓦的冲向$n" HIW "，" + name +
  #               HIW "幻作数道虚影，顿时无数星光一齐射向$n" HIW "！\n" NOR;
  #         message_combatd(msg, me, target);
  # 
  #         ap = me->query_skill("dodge", 1);
  #         dp = target->query_skill("dodge", 1);
  #         if (ap / 2 + random(ap) > dp){
  #             count = ap / 4;
  #         }
  #         else{
  #             count = ap / 8;
  #         }
  #         me->add_temp("apply/attack", count);
  #         me->add_temp("apply/damage", count);
  #         me->add_temp("apply/unarmed_damage", count);
  # 
  #         me->add_temp("pixie-jian/hit_msg", 1);
  # 
  #         for (i = 0; i < 9; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 if (random(3) == 0 && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #             COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  #         me->add("neili", -100);
  #         me->start_busy(1 + random(7));
  #         me->add_temp("apply/attack", -count);
  #         me->add_temp("apply/damage", -count);
  #         me->add_temp("apply/unarmed_damage", -count);
  #         me->delete_temp("pixie-jian/hit_msg");
  #         return 1;
  # }
end
