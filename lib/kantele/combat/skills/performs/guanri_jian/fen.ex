defmodule Kantele.Combat.Skills.Performs.GuanriJian.Fen do
  @moduledoc """
  perform「焚阳剑」（source guanri-jian/fen.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 持剑 → 观日剑法>=150 →
  激发 `sword` 为观日剑法 → 内力上限>=2000 → 真气>=500 → 目标存活。
  起手广播后按 `ap/2 + random(ap) > 目标 force` 判定：命中则目标 qi 伤
  `damage`、qi 上限伤 `damage*75/100`，附加「烈炎剑气」，并令攻击方忙乱 3、
  扣 300 真气；失手则攻击方忙乱 4、扣 100 真气。

  差异（TODO(migrate)）：
  - `.c` 的 `COMBAT_D->do_damage(..., 75, (: final, ...))` 折算为
    `Vitals.damage(:qi, damage)` + `Vitals.wound(:qi, damage*75/100)`；
    `final` 回调的 `affect_by("zhurong_jian", …)` 折算为
    `ConditionEvent.apply_poison/2`（`zhurong_jian.c` 的中文名为「烈炎剑气」）；
  - `.c` 的起手文案 `"…「焚阳剑" + "」划出，手中" + weapon->name() + "携着…"`
    被 `+` 分隔为三段，故用列表 `Enum.join("")` 逐段保留，避免 Elixir 侧
    `<>` 把前两段合并（与 `bagua_dao/mang.ex` 的拆段约定同理）；
  - `.c` 未列「是否已学此招」门槛（`can_perform`），本引擎以框架层
    `perform_known?/2` 统一把关（多出的文案不影响对齐）；
  - `living(target)` 门槛在攻击方无 meta 可查，此处保守恒判存活，
    由目标侧 `combat/perform-incoming` 的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.ConditionEvent
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "guanri-jian/fen"
  @move_name "「焚阳剑」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    ap = Stats.skill(stats, "sword")
    # LPC: damage = ap / 2 + random(ap);
    damage = div(ap, 2) + Engine.rand(rng, ap)
    lvl = Stats.skill(stats, "guanri-jian")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         {:ok, weapon} <- check_weapon(character),
         :ok <- check_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_resources(character),
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

      apply_effect(conn, character, target, weapon)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # 框架层「是否已学此招」门槛（.c 未列 `can_perform`，见 moduledoc 差异说明）。
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
  #         || (string)weapon->query("skill_type") != "sword")
  defp check_weapon(character) do
    case Combat.weapon(character.meta.combat) do
      %{skill_type: "sword"} = weapon -> {:ok, weapon}
      _ -> {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("guanri-jian", 1) < 150)
  defp check_level(stats) do
    if Stats.skill(stats, "guanri-jian") < 150 do
      {:error, "你观日剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "guanri-jian")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") != "guanri-jian" do
      {:error, "你没有激发观日剑法，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("max_neili") < 2000)
  #      if ((int)me->query("neili") < 500)
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2000 ->
        {:error, "你的内力修为不够，难以施展#{@move_name}。\n"}

      vitals.neili < 500 ->
        {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (! living(target))
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

  defp apply_effect(conn, character, target, weapon) do
    # LPC: msg = WHT "$N" WHT "运转内力，陡然一势「" HIR "焚阳剑" NOR
    #            + WHT "」划出，手中" + weapon->name() + WHT "携着一股热"
    #            "流卷向$n" WHT "全身。\n" NOR;
    #      message_combatd(msg, me, target);
    # 三段固定文案被 `+` 分隔，逐段保留（勿用 `<>` 合并前两段）。
    conn
    |> Broadcast.publish(
      Enum.join(
        [
          "$N运转内力，陡然一势「焚阳剑",
          "」划出，手中",
          Map.get(weapon, :name),
          "携着一股热流卷向$n全身。\n"
        ],
        ""
      ),
      n1: character.name,
      n2: target.name
    )
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
    lvl = Map.get(data, :level, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force");
    #      if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > Stats.skill(stats, "force") do
      # LPC: damage = ap / 2 + random(ap);
      #      msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 75,
      #                                 (: final, me, target, damage :));
      #      do_damage: receive_damage("qi", damage); receive_wound("qi", damage*75/100);
      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 75, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC final(): target->affect_by("zhurong_jian",
      #   ([ "level" : lvl + random(lvl), "id" : me->query("id"),
      #      "duration" : lvl / 50 + random(lvl / 20) ]));
      poison_level = lvl + Engine.rand(rng, lvl)
      poison_duration = div(lvl, 50) + Engine.rand(rng, div(lvl, 20))

      conn =
        ConditionEvent.apply_poison(conn, %{
          "level" => poison_level,
          "duration" => poison_duration,
          "remain" => poison_duration,
          "id" => attacker.id,
          "name" => "烈炎剑气"
        })

      # LPC: me->start_busy(3); me->add("neili", -300);
      Performs.feedback(attacker, 300, 3)

      conn
      |> Broadcast.publish(final_message(), bindings)
      |> put_character(character)
    else
      # LPC: msg += CYN "可是$n" CYN "看破了$N" CYN "的企图，斜跃避开。\n" NOR;
      #      me->start_busy(4); me->add("neili", -100);
      Performs.feedback(attacker, 100, 4)

      Broadcast.publish(conn, "可是$n看破了$N的企图，斜跃避开。\n", bindings)
    end
  end

  # LPC final(): return HIR "只听$n" HIR "一声惨嚎，几柱鲜血射出，剑伤"
  #                     "处腾起一道烈火，烧得嗤嗤作响。\n" NOR;
  @doc false
  def final_message, do: "只听$n一声惨嚎，几柱鲜血射出，剑伤处腾起一道烈火，烧得嗤嗤作响。\n"
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define FEN "「" HIR "焚阳剑" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string final(object me, object target, int damage);
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp, damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/guanri-jian/fen"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(FEN "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你所使用的武器不对，难以施展" FEN "。\n");
  # 
  #         if ((int)me->query_skill("guanri-jian", 1) < 150)
  #                 return notify_fail("你观日剑法不够娴熟，难以施展" FEN "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "guanri-jian")
  #                 return notify_fail("你没有激发观日剑法，难以施展" FEN "。\n");
  # 
  #         if ((int)me->query("max_neili") < 2000)
  #                 return notify_fail("你的内力修为不够，难以施展" FEN "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你现在的真气不足，难以施展" FEN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = WHT "$N" WHT "运转内力，陡然一势「" HIR "焚阳剑" NOR +
  #               WHT "」划出，手中" + weapon->name() + WHT "携着一股热"
  #               "流卷向$n" WHT "全身。\n" NOR;
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("force");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 2 + random(ap);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 75,
  #                                            (: final, me, target, damage :));
  # 
  #                 me->start_busy(3);
  #                 me->add("neili", -300);
  #         } else
  #         {
  #                 msg += CYN "可是$n" CYN "看破了$N"
  #                        CYN "的企图，斜跃避开。\n" NOR;
  #                 me->start_busy(4);
  #                 me->add("neili", -100);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
  # 
  # string final(object me, object target, int damage)
  # {
  #         int lvl = me->query_skill("guanri-jian", 1);
  # 
  #         target->affect_by("zhurong_jian",
  #                 ([ "level"    : lvl + random(lvl),
  #                    "id"       : me->query("id"),
  #                    "duration" : lvl / 50 + random(lvl / 20) ]));
  # 
  #         return  HIR "只听$n" HIR "一声惨嚎，几柱鲜血射出，剑伤"
  #                 "处腾起一道烈火，烧得嗤嗤作响。\n" NOR;
  # }
end
