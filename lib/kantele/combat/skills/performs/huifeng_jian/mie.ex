defmodule Kantele.Combat.Skills.Performs.HuifengJian.Mie do
  @moduledoc """
  灭剑「mie」（对照 `kungfu/skill/huifeng-jian/mie.c`）

  回风拂柳剑法绝技：需持剑、激发 sword 为回风拂柳剑法、回风拂柳剑法>=120、
  内功>=180、真气>=500、目标存活。漫天剑影化为一剑直刺，命中判定为
  `random(force) > 目标 force/2 || random(combat_exp) > 目标 combat_exp/2`；
  命中造成 `huifeng-jian + random(huifeng-jian)`（外伤 80%）并扣 150 内力、
  忙乱 2；未命中扣 60 内力、忙乱 3。

  差异（TODO(migrate)）：
  - 引子在攻击方广播，命中/落空在目标侧结算；
  - 攻守双方 force/combat_exp 通过事件数据传递。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "huifeng-jian/mie"
  @move_name "「灭剑」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_mapped(stats),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character) do
      apply_perform(conn, character, target, level, weapon)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, weapon}
    else
      {:error, "你所使用的武器不对，无法施展#{@move_name}。\n"}
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "huifeng-jian" do
      :ok
    else
      {:error, "你没有激发回风拂柳剑法，无法施展#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "huifeng-jian")

    if level < 120 do
      {:error, "你的回风拂柳剑法不够娴熟，无法施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 180 do
      {:error, "你的内功火候不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你现在真气不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, level, weapon) do
    stats = character.meta.stats
    weapon_name = Map.get(weapon, :name, "")

    conn =
      Broadcast.publish(
        conn,
        "$N手中长剑剑芒跃动，剑光暴长，幻出死亡的色彩，剑尖渐渐逼近$n，\n$n看到漫天剑光，抽身后跃，可是只这一刹，$N漫天剑影化为一剑直\n刺$n前胸，快捷无伦，只有一剑！\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: level,
        force: Stats.skill(stats, "force"),
        combat_exp: stats.combat_exp,
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
    weapon_name = Map.get(data, :weapon_name, "")
    level = Map.get(data, :level, 0)
    force = Map.get(data, :force, 0)
    combat_exp = Map.get(data, :combat_exp, 0)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: random(me->query_skill("force")) > target->query_skill("force") / 2 ||
    #      random(me->query("combat_exp")) > target->query("combat_exp") / 2
    hit =
      Engine.rand(rng, max(force, 1)) > div(Stats.skill(stats, "force"), 2) or
        Engine.rand(rng, max(combat_exp, 1)) > div(stats.combat_exp, 2)

    if hit do
      # LPC: me->start_busy(2); damage = huifeng-jian + random(huifeng-jian);
      #      me->add("neili", -150);
      damage = level + Engine.rand(rng, max(level, 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 80, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn =
        Broadcast.publish(
          conn,
          "$n全然无法躲避，" <> weapon_name <> "端端正正扎进在$p的胸口，鲜血登时飞溅而出。\n",
          bindings
        )

      Performs.feedback(attacker, 150, 2)
      put_character(conn, character)
    else
      # LPC: me->start_busy(3); me->add("neili", -60);
      conn =
        Broadcast.publish(
          conn,
          "可是$p轻轻一笑，侧身右转，伸出两指，正弹在$P的剑上，" <>
            weapon_name <> "在$p身侧划过，有惊无险。\n",
          bindings
        )

      Performs.feedback(attacker, 60, 3)
      conn
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "huifeng-jian/mie",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // mie.c  回风拂柳剑法「灭剑」
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define MIE "「" HIR "灭剑" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         object weapon;
  # 
  #         if (userp(me) && ! me->query("can_perform/huifeng-jian/mie"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(MIE "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你所使用的武器不对，无法施展" MIE "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "huifeng-jian")
  #                 return notify_fail("你没有激发回风拂柳剑法，无法施展" MIE "。\n");
  # 
  #         if ((int)me->query_skill("huifeng-jian", 1) < 120)
  #                 return notify_fail("你的回风拂柳剑法不够娴熟，无法施展" MIE "。\n");
  # 
  #         if ((int)me->query_skill("force") < 180)
  #                 return notify_fail("你的内功火候不够，无法施展" MIE "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                return notify_fail("你现在真气不够，无法施展" MIE "。\n");
  # 
  #         if (! living(target))
  #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "手中长剑剑芒跃动，剑光暴长，幻出死亡的色彩，剑尖渐"
  #               "渐逼近$n" HIR "，\n$n" HIR "看到漫天剑光，抽身后跃，可是只这一刹"
  #               "，$N" HIR "漫天剑影化为一剑直\n刺$n" HIR "前胸，快捷无伦，只有一"
  #               "剑！\n" NOR;
  # 
  #         if (random(me->query_skill("force")) > target->query_skill("force") / 2 ||
  #             random(me->query("combat_exp")) > (int)target->query("combat_exp") / 2)
  #         {
  #                 me->start_busy(2);
  #                 damage = (int)me->query_skill("huifeng-jian", 1);
  #                 damage += random(damage);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
  #                                            HIR "$n" HIR "全然无法躲避，" + weapon->name() +
  #                                            HIR "端端正正扎进在$p" HIR "的胸口，鲜血登时飞溅"
  #                                            "而出。\n" NOR);
  #                 me->add("neili", -150);
  #         } else
  #         {
  #                 me->start_busy(3);
  #                 msg += YEL "可是$p" YEL "轻轻一笑，侧身右转，伸"
  #                        "出两指，正弹在$P" YEL "的剑上，" + weapon->name() +
  #                        YEL "在$p" YEL "身侧划过，有惊无险。\n"NOR;
  #                 me->add("neili", -60);
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
