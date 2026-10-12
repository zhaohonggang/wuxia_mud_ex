defmodule Kantele.Combat.Skills.Performs.ChousuiZhang.Tao do
  @moduledoc """
  perform「碧焰滔天」（source chousui-zhang/tao.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 抽髓掌>=220 → 毒技>=250 →
  化功大法>=220 → 内力上限>=3000 → 真气>=3000 → 准备抽髓掌 → 运功中（powerup）→
  手中持有毒药（handing） → 目标存活。前置广播后攻击方忙乱 `4+random(4)`、
  真气清零、内力上限 -50 再 -random(50)。随后按
  `max_neili + random(max_neili) < 目标 max_neili*18/10` 分两支：
  - 回火：攻击方被反噬昏厥（`.c` 由 `unconcious_me` 定时回调执行）；
  - 否则 `ap = poison/2 + force`，`ap + random(ap) < 目标 dodge` 为失手
    （目标忙乱 5），命中则目标 qi 伤 `damage*2`、jing 伤 `damage/2`、
    附加 fire_poison 并忙乱 10（`damage = 1500 + random(lvl*3)`）。

  差异（TODO(migrate)）：
  - `.c` 的 `me->query_skill("force, 1")` 系笔误（其上一行注释掉的
    `//me->query_skill("force")` 即原意），此处按原意取 `force` 等级；
  - `call_out("unconcious_me", 1, me)` 折算为 `Performs.feedback` 的
    `:unconcious` 键（`Kantele.Feature.Damage.unconcious/1` 承接）；
  - `me->want_kill(target)` / `target->kill_ob(me)` 的仇恨建立未实现
    （同 `beiming_shengong/suck.ex`）；
  - `target->affect_by("fire_poison", …)` 折算为 `ConditionEvent.apply_poison/2`
    （`.c` 未给毒名，此处补 `"name"` 供显示）；
  - `if (objectp(du)) destruct(du)` 手中毒药的析构未实现（无毒药物品模型）；
  - `living(target)` 门槛由目标侧 `combat/perform-incoming` 兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.ConditionEvent
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "chousui-zhang/tao"
  @move_name "「碧焰滔天」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "chousui-zhang")
    # LPC: damage = 1500 + random(lvl * 3);
    damage = 1500 + Engine.rand(rng, lvl * 3)
    # LPC: ap = me->query_skill("poison", 1) / 2 + me->query_skill("force, 1");
    #      `"force, 1"` 系笔误，按上一行注释掉的 `//me->query_skill("force")` 原意取 force。
    ap = div(Stats.skill(stats, "poison"), 2) + Stats.skill(stats, "force")
    # LPC 分支判定读的是 me->add("max_neili", -50) 之后的 max_neili，故先取快照。
    max_neili = max(character.meta.vitals.max_neili - 50, 0)

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_prepared(character),
         :ok <- check_powerup(character),
         :ok <- check_handing(character),
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
          max_neili: max_neili,
          jiali: combat.jiali,
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
      [] -> {:error, "你只能对战斗中的对手施展#{@move_name}。\n"}
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "chousui-zhang") < 220 ->
        {:error, "你的抽髓掌火候不够。\n"}

      Stats.skill(stats, "poison") < 250 ->
        {:error, "你的基本毒技火候不够。\n"}

      Stats.skill(stats, "huagong-dafa") < 220 ->
        {:error, "你的化功大法火候不够。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3000 ->
        {:error, "你的内力修为不足，无法用内力施展#{@move_name}。\n"}

      vitals.neili < 3000 ->
        {:error, "你现在内息不足，无法用内力施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "chousui-zhang")
  defp check_prepared(character) do
    stats = character.meta.stats

    case Stats.prepared_perform(stats, "strike") do
      nil ->
        {:error, "你还没有准备抽髓掌，无法施展#{@move_name}。\n"}

      value ->
        if String.split(value, "/") |> hd() == "chousui-zhang" do
          :ok
        else
          {:error, "你还没有准备抽髓掌，无法施展#{@move_name}。\n"}
        end
    end
  end

  # LPC: if (! me->query_temp("powerup"))
  #              return notify_fail("你必须将全身功力尽数提起才能施展" TAO "。\n");
  defp check_powerup(character) do
    if Combat.buff_active?(character.meta.combat, "powerup") do
      :ok
    else
      {:error, "你必须将全身功力尽数提起才能施展#{@move_name}。\n"}
    end
  end

  # LPC: if (! objectp(du = me->query_temp("handing")) && userp(me))
  #              return notify_fail("你首先要拿着(hand)一些毒药作为引子。\n");
  #      if (objectp(du) && ! mapp(du->query("poison")))
  #              return notify_fail(du->name() + "又不是毒药，无法运射出毒焰？\n");
  defp check_handing(character) do
    handing = character.meta |> Map.get(:temp, %{}) |> Map.get("handing")
    handing_name = if is_map(handing), do: Map.get(handing, :name, ""), else: ""

    cond do
      handing == nil ->
        {:error, "你首先要拿着(hand)一些毒药作为引子。\n"}

      not is_map(handing) ->
        {:error, "#{handing_name}又不是毒药，无法运射出毒焰？\n"}

      not is_map(Map.get(Map.get(handing, :meta, %{}), "poison")) ->
        {:error, "#{handing_name}又不是毒药，无法运射出毒焰？\n"}

      true ->
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

  defp apply_effect(conn, character, target) do
    rng = &:rand.uniform/1

    # LPC: me->start_busy(4 + random(4)); me->set("neili", 0); me->add("max_neili", -50);
    #      三个分支里各有一处 me->add("max_neili", -random(50))，实为无条件，此处一并结算。
    vitals = character.meta.vitals
    vitals = %{vitals | neili: 0}
    vitals = %{vitals | max_neili: max(vitals.max_neili - 50, 0)}
    vitals = %{vitals | max_neili: max(vitals.max_neili - Engine.rand(rng, 50), 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    combat = Combat.start_busy(character.meta.combat, 4 + Engine.rand(rng, 4))
    character = %{character | meta: %{character.meta | combat: combat}}

    # LPC: msg = HIR "只见$N" HIR "双目血红，……\n" NOR;  message_vision(msg, me, target);
    conn =
      Broadcast.publish(
        conn,
        "只见$N双目血红，头发散乱，猛地仰天发出一声悲啸。\n\n$N把心一横，在自己舌尖狠命一咬，将毕生功力尽数喷出，顿时只见空气中血雾弥漫，腥臭无比，随即又\n听$N骨骼“噼里啪啦”一阵爆响，双臂顺着喷出的血柱一推，刹那间一座丈来高的奇毒火墙拔地而起，带\n着排山倒海之势向$n涌去！\n",
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
    ap = max(Map.get(data, :ap, 0), 1)
    damage = Map.get(data, :damage, 0)
    lvl = Map.get(data, :level, 0)
    an = Map.get(data, :max_neili, 0)
    jiali = Map.get(data, :jiali, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (me->query("max_neili") + random(me->query("max_neili")) <
    #          target->query("max_neili") * 18 / 10)
    if an + Engine.rand(rng, an) < div(stats.max_neili * 18, 10) do
      # 回火：攻击方被反噬，`call_out("unconcious_me", 1, me)` 令其昏厥。
      Performs.feedback(attacker, %{unconcious: true})

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$n见状连忙提运内力，双臂猛的推出，掌风澎湃，强大的气流顿时将火浪刮得倒转，竟然掉头向$N扑去。\n\n",
          bindings
        )
      )
      |> Broadcast.publish(
        Messages.interpolate("$N一声惨笑，长叹一声，眼前一黑，倒在了地上。\n\n", bindings)
      )
    else
      # LPC: if (ap + random(ap) < target->query_skill("dodge"))
      if ap + Engine.rand(rng, ap) < Stats.skill(stats, "dodge") do
        # LPC: if (! target->is_busy()) target->start_busy(5);
        character = start_busy_unless(character, 5)

        conn
        |> Broadcast.publish(
          Messages.interpolate("$n见势不妙，急忙腾挪身形，避开了$N的攻击。\n", bindings)
        )
        |> put_character(character)
      else
        # LPC: target->receive_damage("qi", damage * 2); target->receive_damage("jing", damage / 2);
        vitals =
          character.meta.vitals
          |> Vitals.damage(:qi, damage * 2)
          |> Vitals.damage(:jing, div(damage, 2))

        character = %{character | meta: %{character.meta | vitals: vitals}}

        # LPC: target->affect_by("fire_poison",
        #          ([ "level" : me->query("jiali") * 3 + random(me->query("jiali") * 2),
        #             "id"    : me->query("id"),
        #             "duration" : lvl / 20 + random(lvl) ]));
        poison_level = jiali * 3 + Engine.rand(rng, jiali * 2)
        poison_duration = div(lvl, 20) + Engine.rand(rng, lvl)

        conn =
          ConditionEvent.apply_poison(conn, %{
            "level" => poison_level,
            "duration" => poison_duration,
            "remain" => poison_duration,
            "id" => attacker.id,
            "name" => "火毒"
          })

        # LPC: if (! target->is_busy()) target->start_busy(10);
        character = start_busy_unless(character, 10)

        conn
        |> Broadcast.publish(
          Messages.interpolate(
            "$n见滔天热浪扑面涌来，只觉眼前一片通红，已被卷入火浪，毒焰席卷全身，连骨头都要烤焦一般。\n",
            bindings
          )
        )
        |> put_character(character)
      end
    end
  end

  # LPC: if (! target->is_busy()) target->start_busy(N);
  defp start_busy_unless(character, rounds) do
    combat = character.meta.combat

    if Combat.busy?(combat) do
      character
    else
      %{character | meta: %{character.meta | combat: Combat.start_busy(combat, rounds)}}
    end
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define TAO "「" HIG "碧焰滔天" NOR "」"
  # 
  # int unconcious_me(object me);
  # 
  # int perform(object me, object target)
  # {
  #         object du;
  #         int damage;
  #         int ap;
  #         string msg;
  #         int lvl;
  # 
  #         if (userp(me) && ! me->query("can_perform/chousui-zhang/tao"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("你只能对战斗中的对手施展" TAO "。\n");
  # 
  #         if ((int)me->query_skill("chousui-zhang", 1) < 220)
  #                 return notify_fail("你的抽髓掌火候不够。\n");
  # 
  #         if ((int)me->query_skill("poison", 1) < 250)
  #                 return notify_fail("你的基本毒技火候不够。\n");
  # 
  #         if ((int)me->query_skill("huagong-dafa", 1) < 220)
  #                 return notify_fail("你的化功大法火候不够。\n");
  # 
  #         if ((int)me->query("max_neili") < 3000)
  #                 return notify_fail("你的内力修为不足，无法用内力施展" TAO "。\n");
  # 
  #         if ((int)me->query("neili") < 3000)
  #                 return notify_fail("你现在内息不足，无法用内力施展" TAO "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "chousui-zhang")
  #                 return notify_fail("你还没有准备抽髓掌，无法施展" TAO "。\n");
  # 
  #         if (! me->query_temp("powerup"))
  #                 return notify_fail("你必须将全身功力尽数提起才能施展" TAO "。\n");
  # 
  #         if (! objectp(du = me->query_temp("handing")) && userp(me))
  #                 return notify_fail("你首先要拿着(hand)一些毒药作为引子。\n");
  # 
  #         if (objectp(du) && ! mapp(du->query("poison")))
  #                 return notify_fail(du->name() + "又不是毒药，无法运射出毒焰？\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "只见$N" HIR "双目血红，头发散乱，猛地仰天发出一声悲啸。\n\n"
  #               "$N" HIR "把心一横，在自己舌尖狠命一咬，将毕生功力尽"
  #               "数喷出，顿时只见空气中血雾弥漫，腥臭无比，随即又\n"
  #               "听$N" HIR "骨骼“噼里啪啦”一阵爆响，双臂顺着喷出的"
  #               "血柱一推，刹那间一座丈来高的奇毒火墙拔地而起，带\n"
  #               "着排山倒海之势向$n" HIR "涌去！\n" NOR;
  #         me->start_busy(4 + random(4));
  #         me->set("neili", 0);
  #         me->add("max_neili", -50);
  # 
  #         lvl = me->query_skill("chousui-zhang", 1);
  #         damage = 1500 + random(lvl * 3);
  # 
  #         if (me->query("max_neili") + random(me->query("max_neili")) <
  #             target->query("max_neili") * 18 / 10)
  #         {
  #                 msg += WHT "$n" WHT "见状连忙提运内力，双臂猛"
  #                        "的推出，掌风澎湃，强大的气流顿时将火浪"
  #                        "刮得倒转，竟然掉头向$N" WHT "扑去。\n\n" NOR;
  #                 msg += HIR "$N" HIR "一声惨笑，长叹一声，眼前一黑，倒在了地上。\n\n" NOR;
  #                 me->add("max_neili", -random(50));
  # 
  #                 remove_call_out("unconcious_me");
  #                 call_out("unconcious_me", 1, me);
  # 
  #         } else
  #         {
  #                 ap = me->query_skill("poison", 1) / 2 +
  #                      me->query_skill("force, 1");
  #                      //me->query_skill("force");
  #                 if (ap + random(ap) < target->query_skill("dodge"))
  #                 {
  #                         msg += CYN "$n" CYN "见势不妙，急忙腾挪身形，避开了$N" CYN "的攻击。\n" NOR;
  #                         me->add("max_neili", -random(50));
  #                         if (! target->is_busy())
  #                                 target->start_busy(5);
  #                 } else
  #                 {
  #                         msg += HIR "$n" HIR "见滔天热浪扑面涌来，只觉眼前一片通红，"
  #                                "已被卷入火浪，毒焰席卷全身，连骨头都要烤焦一般。\n" NOR;
  #                         me->add("max_neili", -random(50));
  #                         target->affect_by("fire_poison",
  #                                        ([ "level" : me->query("jiali") * 3 + random(me->query("jiali") * 2),
  #                                           "id"    : me->query("id"),
  #                                           "duration" : lvl / 20 + random(lvl) ]));
  #                         target->receive_damage("qi", damage * 2);
  #                         target->receive_damage("jing", damage / 2);
  #                         if (! target->is_busy())
  #                                 target->start_busy(10);
  #                 }
  #         }
  # 
  #         if (objectp(du)) destruct(du);
  #         message_vision(msg, me, target);
  #         me->want_kill(target);
  #         if (! target->is_killing(me)) target->kill_ob(me);
  # 
  #         return 1;
  # }
  # 
  # int unconcious_me(object me)
  # {
  #         if (! objectp(me))
  #               return 1;
  # 
  #         if (living(me))
  #               me->unconcious();
  # 
  #         return 1;
  # }
end
