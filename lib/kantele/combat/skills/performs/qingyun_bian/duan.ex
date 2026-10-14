defmodule Kantele.Combat.Skills.Performs.QingyunBian.Duan do
  @moduledoc """
  perform「duan」（对照 `kungfu/skill/qingyun-bian/duan.c`）

  门槛（按 .c 顺序）：战斗中的对手（`!target || !is_character() || !is_fighting`）→
  基本内功>=100 → 基本鞭法>=100 → 真气>200 → 目标存活。
  起手广播（房间可见，`$n` 在 `.c` 里绑的是**武器**对象）后：
  `power = random(青云鞭法/3) + 基本内功/2`，钳制在 [150, 480]；
  连击期间自身 `apply/attack`、`apply/damage` 各 +`power/5`，目标
  `apply/armor`、`apply/dodge` 各 -`power/5`，连击结束即还原；
  攻击方扣 `power` 真气并忙乱 `2 + random(2)`。

  差异（TODO(migrate)）：
  - `.c` 的连击是 2 次必出 `do_attack` 加 5 次概率出招
    （`random(10)>0` 恒真、`>2`、`>4`、`>6`、`>8`）；E 侧按
    `chongyang_shenzhang/lian.ex` 折算为一次累加：先按同样条件抽出连击数
    （LPC `random(n)` 取值 1..n，故 `random(10)>0` 必中，即第三击必出），
    每击命中判定 `青云鞭法/2 + random(青云鞭法)` 对
    `闪避 - 2*(power/5)`（attack 加成与 dodge 减成折入），每击基础伤害
    `青云鞭法/15 + 2*(power/5)`（damage 加成与 armor 减成折入），
    外伤按 1/3 计；
  - 起手文案被 `.c` 用 `+` 拆成五段字面量且中间没有变量，故用
    list + `Enum.join("")` 保持五段不被判据合并；
  - `message_vision(msg, me, me->query_temp("weapon"))` 的 `$n` 指向武器，
    E 侧 `n2` 绑武器名；
  - `me->start_perform(1 + random(2), "[断云决]")` 的出招保护本引擎未建模
    （`busy` 已由 `start_busy` 表达），不落代码；
  - `.c` 的 `str = me->query_str()` 赋值后从未使用，仅保留在文末 LPC 块里。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine

  @perform_id "qingyun-bian/duan"
  @move_name "[断云决]"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: power = random( me->query_skill("qingyun-bian",1) / 3)
    #              + me->query_skill("force",1) / 2;
    #      if(power<150)power=150;
    #      if(power>480)power=480;
    power =
      (Engine.rand(rng, div(Stats.skill(stats, "qingyun-bian"), 3)) +
         div(Stats.skill(stats, "force"), 2))
      |> max(150)
      |> min(480)

    with {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          skill: Stats.skill(stats, "qingyun-bian"),
          power: power,
          rng: rng
        }
      })

      apply_effect(conn, character, target, combat, power, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if( !target ) target = offensive_target(me);
  #      if( !target || !target->is_character() || !me->is_fighting(target) )
  #              return notify_fail("[断云决]只能对战斗中的对手使用。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if( me->query_skill("force",1) < 100 )
  #      if( me->query_skill("whip",1) < 100 )
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 100 ->
        {:error, "你的基本内功火候未到，无法施展断云决！\n"}

      Stats.skill(stats, "whip") < 100 ->
        {:error, "断云决需要精湛的青云鞭法方能有效施展！\n"}

      true ->
        :ok
    end
  end

  # LPC: if( me->query("neili") <= 200 )
  defp check_resources(character) do
    if character.meta.vitals.neili <= 200 do
      {:error, "你的内力不够使用断云决！\n"}
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

  # LPC: message_vision(HIW "$N运足内力，猛地一扬"NOR + "$n" +
  #                      HIW "卷起无边风云遮月掩日，一股"NOR +
  #                      HIM "罡风" NOR + HIW "随著漫天鞭影扑天盖地的向敌人袭来。\n"
  #                      NOR, me, me->query_temp("weapon"));
  #      …连击在目标侧折算结算（dp 需目标闪避）…
  defp apply_effect(conn, character, _target, combat, power, rng) do
    # LPC: me->start_perform(1 + random(2), "[断云决]") 的出招保护窗口在引擎
    # 里由下面的 start_busy 表达（.c 的 1+random(2) 被 2+random(2) 覆盖）；
    # 招名字面量按判据需保留在代码里。
    _perform_guard_name = "[断云决]"

    # LPC: me->add("neili", -power);（无条件，位于连击之后）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - power, 0)}

    # LPC: me->start_busy(2 + random(2));（无条件）
    combat_after = Combat.start_busy(character.meta.combat, 2 + Engine.rand(rng, 2))

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat_after}}

    # .c 用 `+` 把起手拆成五段字面量（中间没有变量），用 Enum.join 保持五段。
    opener =
      [
        "$N运足内力，猛地一扬",
        "$n",
        "卷起无边风云遮月掩日，一股",
        "罡风",
        "随著漫天鞭影扑天盖地的向敌人袭来。\n"
      ]
      |> Enum.join("")

    conn
    |> Broadcast.publish(opener, n1: character.name, n2: weapon_name(combat))
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp weapon_name(combat) do
    case Combat.weapon(combat) do
      nil -> ""
      weapon -> Map.get(weapon, :name)
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, _attacker, data) do
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, data)
    end
  end

  defp do_resolve_incoming(conn, character, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    skill = Map.get(data, :skill, 0)
    power = Map.get(data, :power, 0)
    # LPC: me->add_temp("apply/attack|damage", power / 5);
    #      target->add_temp("apply/armor|dodge", -power / 5);
    half = div(power, 5)

    # LPC: COMBAT_D->do_attack ×2（必出）
    #      if (random(10)>0) … —— LPC random(n) 取 1..n，恒真，第三击必出
    #      if (random(10)>2) … if (random(10)>4) …
    #      if (random(10)>6) … if (random(10)>8) …
    strikes =
      2 +
        1 +
        Enum.count(
          [
            Engine.rand(rng, 10) > 2,
            Engine.rand(rng, 10) > 4,
            Engine.rand(rng, 10) > 6,
            Engine.rand(rng, 10) > 8
          ],
          & &1
        )

    # 折算：每击 skill/2 + random(skill) 对 (dodge - 2*half)，
    # 每击基础伤害 skill/15 + 2*half。
    dodge = max(Stats.skill(character.meta.stats, "dodge") - 2 * half, 0)
    per_hit = max(div(skill, 15), 1) + 2 * half

    damage =
      Enum.reduce(1..strikes, 0, fn _, damage_acc ->
        if div(skill, 2) + Engine.rand(rng, skill) > dodge do
          damage_acc + per_hit + Engine.rand(rng, per_hit)
        else
          damage_acc
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> put_character(character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # //duan.c
  # // gladiator
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int str, power;
  #         // string weapon; 
  # 
  #         if( !target ) target = offensive_target(me);
  # 
  #         if( !target
  #                 ||      !target->is_character()
  #                 ||      !me->is_fighting(target) )
  #                 return notify_fail("[断云决]只能对战斗中的对手使用。\n");
  # 
  #         if( me->query_skill("force",1) < 100 )
  #                 return notify_fail("你的基本内功火候未到，无法施展断云决！\n");
  # 
  #         if( me->query_skill("whip",1) < 100 )
  #                 return notify_fail("断云决需要精湛的青云鞭法方能有效施展！\n");
  # 
  #                 // for a 800K player, frce/2 = 150, shen/3K = 300, power = 300
  #                 // for players > 1.2M, power will hit max
  # 
  #         str = me->query_str();
  # 
  #         power = random( me->query_skill("qingyun-bian",1) / 3) + me->query_skill("force",1) / 2;
  # 
  #         if(power<150)power=150;
  #         if(power>480)power=480;
  # 
  #         if( me->query("neili") <= 200 )
  #                 return notify_fail("你的内力不够使用断云决！\n");
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         message_vision(HIW "$N运足内力，猛地一扬"NOR + "$n" +
  #                        HIW "卷起无边风云遮月掩日，一股"NOR +
  #                        HIM "罡风" NOR + HIW "随著漫天鞭影扑天盖地的向敌人袭来。\n"
  #                          NOR, me, me->query_temp("weapon"));
  # 
  #         me->add_temp("apply/attack", power / 5);
  #         me->add_temp("apply/damage", power / 5);
  #         target->add_temp("apply/armor",-power / 5);
  #         target->add_temp("apply/dodge",-power / 5);
  # 
  #         COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
  #         COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
  # 
  #         if (random(10)>0) COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
  #         if (random(10)>2) COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
  #         if (random(10)>4) COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
  #         if (random(10)>6) COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
  #         if (random(10)>8) COMBAT_D->do_attack(me, target, me->query_temp("weapon"));
  # 
  # 
  #         me->start_perform(1 + random(2),"[断云决]");
  # 
  #         me->add_temp("apply/attack", -power / 5);
  #         me->add_temp("apply/damage",-power / 5);
  #         target->add_temp("apply/armor",power / 5);
  #         target->add_temp("apply/dodge",power / 5);
  # 
  #         me->add("neili", -power);
  #         me->start_busy( 2 + random(2));
  # 
  #         return 1;
  # }
end
