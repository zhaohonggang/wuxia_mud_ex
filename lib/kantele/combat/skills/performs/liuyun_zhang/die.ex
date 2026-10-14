defmodule Kantele.Combat.Skills.Performs.LiuyunZhang.Die do
  @moduledoc """
  perform「流云叠影」（source liuyun-zhang/die.c，inherit F_SSERVER）

  手工补齐：门槛文案按字符串宏 `DIE`（→「流云叠影」）展开；`random(ap) > dp/2`
  命中判定、分档内力/忙乱（命中 neili-80/busy1 + 目标置忙，失手 neili-30/busy2）
  按原始 LPC 语义建模。目标忙乱门槛在目标侧结算。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "liuyun-zhang/die"

  # LPC: #define DIE "「" HIW "流云叠影" NOR "」"
  @move_name "「流云叠影」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(stats),
         :ok <- check_resources(character),
         :ok <- check_mapped(stats) do
      # LPC: ap = me->query_skill("liuyun-zhang", 1) + me->query_skill("dodge", 1) / 2;
      ap = Stats.skill(stats, "liuyun-zhang") + div(Stats.skill(stats, "dodge"), 2)

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
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("liuyun-zhang", 1) < 100)
  #      if (me->query_skill("dodge") < 150)
  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "liuyun-zhang") < 100 ->
        {:error, "你流云掌不够娴熟，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "dodge") < 150 ->
        {:error, "你的轻功修为不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("neili") < 200)
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "liuyun-zhang")
  #      if (me->query_skill_prepared("strike") != "liuyun-zhang")
  defp check_mapped(stats) do
    cond do
      Stats.mapped(stats, "strike") != "liuyun-zhang" ->
        {:error, "你没有激发流云掌，难以施展#{@move_name}。\n"}

      prepared_is_not?(stats, "strike", "liuyun-zhang") ->
        {:error, "你没有准备流云掌，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC query_skill_prepared 返回绝招 ID（如 "liuyun-zhang/die"），需按技能前缀比对。
  defp prepared_is_not?(stats, skill, mapped) do
    case Stats.prepared_perform(stats, skill) do
      nil -> true
      prepared -> hd(String.split(prepared, "/")) != mapped
    end
  end

  # 本式无「无条件」消耗：neili/busy 均分档（见 resolve_incoming 的 feedback）。
  defp apply_effect(conn, character, target) do
    # LPC: msg = HIC "\n$N" HIC "身法陡然变快，双掌不断拍出，招式如影"
    #               "如幻，虚实难测，试图扰乱$n" HIC "的攻势。" NOR;（合并为单段）
    conn =
      Broadcast.publish(
        conn,
        "\n$N身法陡然变快，双掌不断拍出，招式如影如幻，虚实难测，试图扰乱$n的攻势。",
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

  # LPC: if (target->is_busy()) return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 目标忙乱状态只在目标侧可见，故死亡/忙乱门槛在 resolve_incoming 结算。
  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    cond do
      character.meta.combat.dead ->
        Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？",
          n1: attacker.name,
          n2: character.name
        )

      character.meta.combat.busy > 0 ->
        Broadcast.publish(conn, "$n目前正自顾不暇，放胆攻击吧。",
          n1: attacker.name,
          n2: character.name
        )

      true ->
        do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    stats = character.meta.stats
    # LPC: dp = target->query_skill("dodge");
    dp = Stats.skill(stats, "dodge")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(ap) > dp / 2)
    if Engine.rand(rng, ap) > div(dp, 2) do
      # LPC: target->start_busy(ap / 45 + 1);
      combat = Combat.start_busy(character.meta.combat, div(ap, 45) + 1)
      character = %{character | meta: %{character.meta | combat: combat}}

      # LPC: me->start_busy(1); me->add("neili", -80);（仅命中分支）
      _ = Performs.feedback(attacker, 80, 1)

      # LPC: HIY "$n" HIY "只见$N" HIY "双掌飘忽不定，毫" "无破绽，竟被困在$N"
      #      HIY "的掌风之中。\n" NOR;（合并为单段）
      conn
      |> Broadcast.publish("$n只见$N双掌飘忽不定，毫无破绽，竟被困在$N的掌风之中。\n", bindings)
      |> put_character(character)
    else
      # LPC: me->start_busy(2); me->add("neili", -30);（仅失手分支）
      _ = Performs.feedback(attacker, 30, 2)

      # LPC: CYN "$n" CYN "看破$N" CYN "毫无攻击之意，于" "是大胆反攻，将$N"
      #      CYN "这招尽数化解。\n" NOR;（合并为单段）
      conn
      |> Broadcast.publish("$n看破$N毫无攻击之意，于是大胆反攻，将$N这招尽数化解。\n", bindings)
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DIE "「" HIW "流云叠影" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/liuyun-zhang/die"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(DIE "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(DIE "只能空手施展。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if ((int)me->query_skill("liuyun-zhang", 1) < 100)
  #                 return notify_fail("你流云掌不够娴熟，难以施展" DIE "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "liuyun-zhang")
  #                 return notify_fail("你没有激发流云掌，难以施展" DIE "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "liuyun-zhang")
  #                 return notify_fail("你没有准备流云掌，难以施展" DIE "。\n");
  # 
  #         if (me->query_skill("dodge") < 150)
  #                 return notify_fail("你的轻功修为不够，难以施展" DIE "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够，难以施展" DIE "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("liuyun-zhang", 1) +
  #              me->query_skill("dodge", 1) / 2;
  # 
  #         dp = target->query_skill("dodge");
  # 
  #         msg = HIC "\n$N" HIC "身法陡然变快，双掌不断拍出，招式如影"
  #               "如幻，虚实难测，试图扰乱$n" HIC "的攻势。" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #         if (random(ap) > dp / 2)
  #         {
  #         msg = HIY "$n" HIY "只见$N" HIY "双掌飘忽不定，毫"
  #                       "无破绽，竟被困在$N" HIY "的掌风之中。\n" NOR;
  # 
  #                 target->start_busy(ap / 45 + 1);
  #                    me->start_busy(1);
  #                 me->add("neili", -80);
  #         } else
  #         {
  #                 msg = CYN "$n" CYN "看破$N" CYN "毫无攻击之意，于"
  #                       "是大胆反攻，将$N" CYN "这招尽数化解。\n" NOR;
  # 
  #                 me->start_busy(2);
  #                 me->add("neili", -30);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
