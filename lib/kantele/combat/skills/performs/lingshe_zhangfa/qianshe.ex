defmodule Kantele.Combat.Skills.Performs.LingsheZhangfa.Qianshe do
  @moduledoc """
  perform「千蛇出洞」（source lingshe-zhangfa/qianshe.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 持杖类武器 → 内功>=150 →
  真气>=100 → 灵蛇杖法>=120 → 激发 staff 为灵蛇杖法 → 目标存活。
  前置广播后攻击方扣 100 真气；命中判定 `lvl/2 + random(lvl)` > 目标 `parry*2/3`，
  命中则 apply/attack 的 lvl/6 加成折入每击伤害；连续 `do_attack` 5 击，
  每击 `random(2)` 有几率令目标忙乱 1；收招忙乱 `1+random(5)`。

  差异（TODO(migrate)）：
  - LPC 的 5 次 `COMBAT_D->do_attack` 折算为每击 `level/15`（+命中分支 lvl/6）
    基础伤害 + 命中判定 `level/2 + random(level)` vs 目标 `dodge`；
  - 命中分支 `add_temp("apply/attack", count)` … `add_temp(-count)` 的临时
    加成折入每击伤害，不落攻击方 temp（避免残留 buff）；
  - 每击的 `random(2) && ! target->is_busy()` 折算为每击几率累积，收招后
    `not Combat.busy?` 时 start_busy(1)（同 kuihua-mogong/tian）。
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

  @perform_id "lingshe-zhangfa/qianshe"
  @move_name "「千蛇出洞」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "lingshe-zhangfa")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_force(character),
         :ok <- check_resources(character),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_target_alive(target) do
      weapon_name =
        case Combat.weapon(combat) do
          nil -> ""
          weapon -> Map.get(weapon, :name)
        end

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          weapon_name: weapon_name,
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

  # LPC: if (userp(me) && ! me->query("can_perform/lingshe-zhangfa/qianshe"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你还不会使用#{@move_name}。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon) || weapon->query("skill_type") != "staff")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if is_map(weapon) and Map.get(weapon, :skill_type) == "staff" do
      :ok
    else
      {:error, "你必须手持一把杖才能施展#{@move_name}！\n"}
    end
  end

  # LPC: if ((int)me->query_skill("force") < 150)
  defp check_force(character) do
    if Stats.skill(character.meta.stats, "force") < 150 do
      {:error, "你的内功火候不够，难以施展#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 100)
  defp check_resources(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你的真气不够，无法施展#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if ((lvl = me->query_skill("lingshe-zhangfa", 1)) < 120)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "lingshe-zhangfa") < 120 do
      # 注意：.c 中此两句未加「」书名号
      {:error, "你的灵蛇杖法还不到家，无法使用千蛇出洞！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("staff") != "lingshe-zhangfa")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "staff") == "lingshe-zhangfa" do
      :ok
    else
      # 注意：.c 中此句未加「」书名号
      {:error, "你没有激发灵蛇杖法，无法使用千蛇出洞！\n"}
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

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIW "$N" HIW "大喝一声，扑身上前，手中的" + weapon->name() +
    #      HIW "化作万道光芒，一齐射向$n" HIW "！\n" NOR;
    #      me->add("neili", -100);
    # 命中分支文案与连击伤害在目标侧结算。
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 100, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    weapon_name =
      case Combat.weapon(character.meta.combat) do
        nil -> ""
        weapon -> Map.get(weapon, :name)
      end

    conn =
      Broadcast.publish(
        conn,
        "$N大喝一声，扑身上前，手中的" <> weapon_name <> "化作万道光芒，一齐射向$n！\n",
        n1: character.name,
        n2: target.name
      )

    conn
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
    level = max(Map.get(data, :level, 0), 1)
    weapon_name = Map.get(data, :weapon_name, "")
    stats = character.meta.stats
    dp = div(Stats.skill(stats, "parry") * 2, 3)
    dodge = Stats.skill(stats, "dodge")

    # LPC: if (lvl / 2 + random(lvl) > target->query_skill("parry") * 2 / 3)
    hit? = div(level, 2) + Engine.rand(rng, level) > dp
    count = if hit?, do: div(level, 6), else: 0
    per_hit = max(div(level, 15), 1) + count

    # LPC: for (i = 0; i < 5; i++) { if (! me->is_fighting(target)) break;
    #         if (random(2) && ! target->is_busy()) target->start_busy(1);
    #         COMBAT_D->do_attack(me, target, weapon, 0); }
    {damage, busy_roll?} =
      Enum.reduce(1..5, {0, false}, fn _, {damage_acc, busy_acc} ->
        hit_flag? = div(level, 2) + Engine.rand(rng, level) > dodge
        busy_acc = busy_acc or Engine.rand(rng, 2) == 1
        damage_acc = if hit_flag?, do: damage_acc + per_hit + Engine.rand(rng, per_hit), else: damage_acc
        {damage_acc, busy_acc}
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    combat = character.meta.combat
    combat = if busy_roll? and not Combat.busy?(combat), do: Combat.start_busy(combat, 1), else: combat
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    # LPC: me->start_busy(1 + random(5))（收招后，位于连击之后）
    Performs.feedback(attacker, 0, 1 + Engine.rand(rng, 5))

    if hit? do
      # LPC: HIY "$n" HIY "见$N" HIY "把" + weapon->name() +
      #      HIY "使得活灵活现，犹如真物一般，实在是难以抵挡，只有后退。\n" NOR
      conn
      |> Broadcast.publish(
        "$n见$N把" <> weapon_name <> "使得活灵活现，犹如真物一般，实在是难以抵挡，只有后退。\n",
        n1: attacker.name,
        n2: character.name
      )
      |> put_character(character)
    else
      # LPC 未命中分支无文案（仅 count = 0）
      conn
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int count;
  #         int lvl;
  #         int i;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/lingshe-zhangfa/qianshe"))
  #                 return notify_fail("你还不会使用「千蛇出洞」。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("「千蛇出洞」只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "staff")
  #                 return notify_fail("你必须手持一把杖才能施展「千蛇出洞」！\n");
  # 
  #         if ((int)me->query_skill("force") < 150)
  #                 return notify_fail("你的内功火候不够，难以施展「千蛇出洞」！\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你的真气不够，无法施展「千蛇出洞」！\n");
  # 
  #         if ((lvl = (int)me->query_skill("lingshe-zhangfa", 1)) < 120)
  #                 return notify_fail("你的灵蛇杖法还不到家，无法使用千蛇出洞！\n");
  # 
  #         if (me->query_skill_mapped("staff") != "lingshe-zhangfa")
  #                 return notify_fail("你没有激发灵蛇杖法，无法使用千蛇出洞！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "大喝一声，扑身上前，手中的" + weapon->name() +
  #               HIW "化作万道光芒，一齐射向$n" HIW "！\n" NOR;
  # 
  #         if (lvl / 2 + random(lvl) > target->query_skill("parry") * 2 / 3)
  #         {
  #                 msg += HIY "$n" HIY "见$N" HIY "把" + weapon->name() +
  #                        HIY "使得活灵活现，犹如真物一般，实在是难以抵挡，只有后退。\n" NOR;
  #                 count = lvl / 6;
  #                 me->add_temp("apply/attack", count);
  #         } else
  #                 count = 0;
  # 
  #         message_combatd(msg, me, target);
  #         me->add("neili", -100);
  # 
  #         for (i = 0; i < 5; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(2) && ! target->is_busy())
  #                         target->start_busy(1);
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -count);
  #         me->start_busy(1 + random(5));
  #         return 1;
  # }
end
