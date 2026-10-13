defmodule Kantele.Combat.Skills.Performs.JingzhongBafa.Bafa do
  @moduledoc """
  perform「井中八法」（source jingzhong-bafa/bafa.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标为战斗中的对手 → 手持 blade → 真气>=500 →
  基本内功>=300 → 井中八法>=200 → 激发 blade 为井中八法。
  （`.c` 无 `can_perform`，也无 `living(target)` 检查。）
  起手广播（含武器名）后按 `random(基本刀法) vs 目标 parry/3` 判定：
  命中播报「出了破绽」并把攻击加成置为 `井中八法/3`，未命中播报「小心接招」且加成为 0；
  随后连出 8 击（`COMBAT_D->do_attack`）。
  攻击方无条件扣 150 真气并忙乱 `1+random(6)`。

  差异（TODO(migrate)）：
  - `.c` 无 `can_perform` 门槛，故不设「已知此招」检查（调用点由
    `perform_command.ex` 的 `perform_list` 放行）；
  - 命中判定需目标 `parry`，故两支文案与 `count` 加成均在目标侧结算；
  - 8 次 `COMBAT_D->do_attack` 折算为每击 `level` 基础判定 + 伤害
    （`level = 井中八法 + count`，`count` 即 `.c` 的 `add_temp("apply/attack", count)`）；
  - `.c` 第 44 行 `count = me->query_skill("jingzhong-bafa)", 1) / 3;` 为源码笔误
    （多一个 `"` 与 `)`），按语义取 `井中八法/3`；
  - `.c` 起手式把武器名插在中文串中间，按约定写成 `"A" <> weapon_name <> "B"` 两段；
  - `.c` 循环内的 `if (! me->is_fighting(target)) break;` 未建模（目标侧单次结算）。
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

  @perform_id "jingzhong-bafa/bafa"
  @move_name "井中八法"

  # LPC: for (i = 0; i < 8; i++) COMBAT_D->do_attack(me, target, weapon, 0);
  @strikes 8

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jingzhong-bafa")
    # LPC: random(me->query_skill("blade"))
    blade = Stats.skill(stats, "blade")
    # LPC: count = me->query_skill("jingzhong-bafa)", 1) / 3;  （源码笔误，语义为 /3）
    count_base = div(lvl, 3)

    with {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_resources(character),
         :ok <- check_levels(character),
         :ok <- check_mapped(character) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          blade: blade,
          count_base: count_base,
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

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #          (string)weapon->query("skill_type") != "blade")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon != nil and Map.get(weapon, :skill_type) == "blade" do
      :ok
    else
      {:error, "手中没刀还使什么#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query("neili") < 500)
  defp check_resources(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你的真气不够！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("force") < 300)
  #      / if ((int)me->query_skill("jingzhong-bafa", 1) < 200)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 300 ->
        {:error, "你的内功火候不够！\n"}

      Stats.skill(stats, "jingzhong-bafa") < 200 ->
        {:error, "你的#{@move_name}还不到家，无法施展绝招。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("blade") != "jingzhong-bafa")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "blade") == "jingzhong-bafa" do
      :ok
    else
      {:error, "你没有激发#{@move_name}，无法施展绝招。\n"}
    end
  end

  defp apply_effect(conn, character, target, rng) do
    # LPC: msg = HIY "$N" HIY "一声清啸，手中的" + weapon->name() +
    #            HIY "将「井中八法」一齐施出，刀法变化莫测，笼罩了$n" HIY "周身要害！\n" NOR;
    #      message_combatd(msg, me, target); me->add("neili", -150);
    #      8 × COMBAT_D->do_attack(me, target, weapon, 0);
    #      me->start_busy(1 + random(6));
    weapon = Combat.weapon(character.meta.combat) || %{}
    weapon_name = Map.get(weapon, :name, "")
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 150}
    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 6))
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    msg =
      [
        "$N一声清啸，手中的",
        weapon_name,
        "将「#{@move_name}」一齐施出，刀法变化莫测，笼罩了$n周身要害！\n"
      ]
      |> Enum.join("")

    conn
    |> Broadcast.publish(msg, n1: character.name, n2: target.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # .c 无 living(target) 门槛，此处仍按本仓库惯例做死亡短路
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    level = max(Map.get(data, :level, 0), 1)
    blade = max(Map.get(data, :blade, 0), 1)
    count_base = Map.get(data, :count_base, 0)
    strikes = Map.get(data, :strikes, @strikes)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query_skill("blade")) > target->query_skill("parry") / 3)
    {conn, count} =
      if Engine.rand(rng, blade) > div(Stats.skill(stats, "parry"), 3) do
        # LPC: msg += HIR "$n" HIR "见来招实在是变幻莫测，不由得心" "生惧意，招式登时出了破绽！\n" NOR;
        #      count = me->query_skill("jingzhong-bafa", 1) / 3;
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$n见来招实在是变幻莫测，不由得心生惧意，招式登时出了破绽！\n",
              bindings
            )
          )

        {conn, count_base}
      else
        # LPC: msg += HIC "$n" HIC "心底微微一惊，打起精神小心接招。\n" NOR; count = 0;
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate("$n心底微微一惊，打起精神小心接招。\n", bindings)
          )

        {conn, 0}
      end

    lvl = level + count
    dodge = Stats.skill(stats, "dodge")

    # LPC 连击 8 次，每次 COMBAT_D->do_attack(me, target, weapon, 0)
    damage =
      Enum.reduce(1..strikes, 0, fn _, acc ->
        if div(lvl, 2) + Engine.rand(rng, lvl) > dodge do
          acc + lvl + Engine.rand(rng, lvl)
        else
          acc
        end
      end)

    vitals =
      if damage > 0 do
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage, 3))
      else
        character.meta.vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> put_character(character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int count;
  #         int i;
  #  
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("井中八法只能对战斗中的对手使用。\n");
  #  
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "blade")
  #                 return notify_fail("手中没刀还使什么井中八法。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你的真气不够！\n");
  # 
  #         if ((int)me->query_skill("force") < 300)
  #                 return notify_fail("你的内功火候不够！\n");
  # 
  #         if ((int)me->query_skill("jingzhong-bafa", 1) < 200)
  #                 return notify_fail("你的井中八法还不到家，无法施展绝招。\n");
  # 
  #         if (me->query_skill_mapped("blade") != "jingzhong-bafa")
  #                 return notify_fail("你没有激发井中八法，无法施展绝招。\n");
  # 
  #         msg = HIY "$N" HIY "一声清啸，手中的" + weapon->name() +
  #               HIY "将「井中八法」一齐施出，刀法变化莫测，笼罩了$n" HIY "周身要害！\n" NOR;
  # 
  #         if (random(me->query_skill("blade")) > target->query_skill("parry") / 3)
  #         {
  #                 msg += HIR "$n" HIR "见来招实在是变幻莫测，不由得心"
  #                        "生惧意，招式登时出了破绽！\n" NOR;
  #                 count = me->query_skill("jingzhong-bafa)", 1) / 3;
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "心底微微一惊，打起精神小心接招。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #         message_combatd(msg, me, target);
  #         me->add("neili", -150);
  #         me->add_temp("apply/attack", count);
  # 
  #         for (i = 0; i < 8; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(3) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -count);
  #         me->start_busy(1 + random(6));
  #         return 1;
  # }
end
