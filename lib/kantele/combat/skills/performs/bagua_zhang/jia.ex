defmodule Kantele.Combat.Skills.Performs.BaguaZhang.Jia do
  @moduledoc """
  perform「掌中夹镖」（source bagua-zhang/jia.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
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
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "bagua-zhang/jia"
  @move_name "「掌中夹镖」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "bagua-zhang")
    ap = (Stats.skill(stats, "strike") + Stats.skill(stats, "throwing"))
    damage = (div(ap, 4) + Engine.rand(rng, div(ap, 4)))
    anqi = handing_anqi(character)
    anqi_unit = anqi && Map.get(anqi.meta, :unit)
    anqi_name = anqi && anqi.name

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          damage: damage,
          anqi_unit: anqi_unit,
          anqi_name: anqi_name,
          rng: rng
        }
      })

      apply_effect(conn, character, target, anqi)
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

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  # LPC 门槛顺序：空手 → 手持暗器 → mapped/prepared(strike) → mapped(throwing)
  #               → bagua-zhang<120 → bagua-biao<120 → force<150 → neili<150
  defp check_gates(character) do
    with :ok <- check_weapon(character),
         :ok <- check_anqi(character),
         :ok <- check_mapped(character),
         :ok <- check_levels(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "bagua-zhang") < 120 -> {:error, "你的八卦掌不够娴熟，难以施展#{@move_name}。\n"}
      Stats.skill(stats, "bagua-biao") < 120 -> {:error, "你的八卦镖诀不够娴熟，难以施展#{@move_name}。\n"}
      Stats.skill(stats, "force") < 150 -> {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "bagua-zhang" ->
        {:error, "你没有激发八卦掌，难以施展#{@move_name}。\n"}

      Stats.prepared_perform(stats, "strike") == nil or String.split(Stats.prepared_perform(stats, "strike"), "/") |> hd() != "bagua-zhang" ->
        {:error, "你没有准备八卦掌，难以施展#{@move_name}。\n"}

      Stats.mapped(stats, "throwing") != "bagua-biao" ->
        {:error, "你没有激发八卦镖诀，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 150 -> {:error, "你现在真气不足，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    combat = character.meta.combat

    cond do
      Combat.weapon(combat) != nil -> {:error, "#{@move_name}只能空手施展。\n"}
      true -> :ok
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("handing")) ||
  #          weapon->query("skill_type") != "throwing")
  #         return notify_fail("你现在手中并没有拿着暗器。\n");
  defp check_anqi(character) do
    if has_throwing_anqi?(character) do
      :ok
    else
      {:error, "你现在手中并没有拿着暗器。\n"}
    end
  end

  defp apply_effect(conn, character, target, anqi) do
    # LPC: me->add("neili", -100); weapon->add_amount(-1); me->start_busy(2);
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = Combat.start_busy(character.meta.combat, 2)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}
    character = consume_anqi(character, anqi)

    conn =
      Broadcast.publish(
        conn,
        "$N一声暴喝，一掌重重击向$n，$p正欲格挡，忽然只见眼前金光一闪，一股劲风已由$N掌中激射而出！\n",
        n1: character.name,
        n2: target.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？", n1: attacker.name, n2: character.name)
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    ap = Map.get(data, :ap, 0)
    damage = Map.get(data, :damage, 0)
    unit = Map.get(data, :anqi_unit) || ""
    anqi_name = Map.get(data, :anqi_name) || ""
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("dodge") + target->query_skill("parry");
    #      if (ap / 2 + random(ap) > dp)
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    hit = div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp

    if hit do
      # LPC: damage = ap/4 + random(ap/4);
      #      receive_damage("qi", damage*3/2); receive_wound("qi", damage);
      #      me->add("neili", -100); me->start_busy(2)
      dmg = div(ap, 4) + Engine.rand(rng, max(div(ap, 4), 1))
      vitals = character.meta.vitals
      vitals = Vitals.damage(vitals, :qi, div(dmg * 3, 2))
      vitals = Vitals.wound(vitals, :qi, dmg)
      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC 命中消息以 weapon 的 base_unit + name 插在句中（"…$N那" + unit + name + "正好打…"）
      msg =
        Messages.interpolate(
          "$n果真始料不及，$N那" <> unit <> anqi_name <> "正好打在$p要穴上，顿时血气上涌，连退数步！\n",
          bindings
        )

      conn
      |> Broadcast.publish(msg)
      |> put_character(character)
    else
      Broadcast.publish(
        conn,
        Messages.interpolate("可是$p早料得$P有此一着，哈哈一笑，斜跳闪开。\n", bindings)
      )
    end
  end

  # 手持暗器：inventory 中带 handing 标记且 skill_type=="throwing" 的实例
  # （对应 LPC `me->query_temp("handing")`，其 base_unit/name 用于命中消息插值）
  defp handing_anqi(character) do
    Enum.find(character.inventory, fn item ->
      is_map(item.meta) and
        Map.get(item.meta, :handing) and
        Map.get(item.meta, :skill_type) == "throwing" and
        (Map.get(item.meta, :amount) || 1) >= 1
    end)
  end

  defp has_throwing_anqi?(character), do: handing_anqi(character) != nil

  # LPC: weapon->add_amount(-1)；数量归零则移除该实例。
  defp consume_anqi(character, anqi) do
    if anqi do
      inventory =
        character.inventory
        |> Enum.map(fn item ->
          if item == anqi do
            amount = (Map.get(item.meta, :amount) || 1) - 1
            if amount >= 1, do: %{item | meta: Map.put(item.meta, :amount, amount)}, else: nil
          else
            item
          end
        end)
        |> Enum.reject(&is_nil/1)

      %{character | inventory: inventory}
    else
      character
    end
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}], "assign_refs": [{"ap", "strike"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(2);"], "level_gates": [{"bagua-biao", "120"}, {"bagua-zhang", "120"}, {"force", "150"}], "map_gates": [{"strike", "bagua-zhang"}, {"throwing", "bagua-biao"}], "prepared_gates": [{"strike", "bagua-zhang"}], "remote_damage": false, "resource_gates": [{"neili", "150"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include "/kungfu/skill/eff_msg.h";
  # 
  # #define JIA "「" HIY "掌中夹镖" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int ap, dp, damage, p;
  #         string pmsg;
  #         string msg;
  #         object weapon;
  # 
  #         if (userp(me) && ! me->query("can_perform/bagua-zhang/jia"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JIA "只能在战斗中对对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(JIA "只能空手施展。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("handing")) ||
  #             (string)weapon->query("skill_type") != "throwing")
  #                 return notify_fail("你现在手中并没有拿着暗器。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "bagua-zhang")
  #                 return notify_fail("你没有激发八卦掌，难以施展" JIA "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "bagua-zhang")
  #                 return notify_fail("你没有准备八卦掌，难以施展" JIA "。\n");
  # 
  #         if (me->query_skill_mapped("throwing") != "bagua-biao")
  #                 return notify_fail("你没有激发八卦镖诀，难以施展" JIA "。\n");
  # 
  #         if ((int)me->query_skill("bagua-zhang", 1) < 120)
  #                 return notify_fail("你的八卦掌不够娴熟，难以施展" JIA "。\n");
  # 
  #         if ((int)me->query_skill("bagua-biao", 1) < 120)
  #                 return notify_fail("你的八卦镖诀不够娴熟，难以施展" JIA "。\n");
  # 
  #         if ((int)me->query_skill("force") < 150)
  #                 return notify_fail("你的内功火候不够，难以施展" JIA "。\n");
  # 
  #         if ((int)me->query("neili") < 150)
  #                 return notify_fail("你现在真气不足，难以施展" JIA "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         me->add("neili", -100);
  #         weapon->add_amount(-1);
  # 
  #         msg = HIY "$N" HIY "一声暴喝，一掌重重击向$n" HIY "，$p" HIY
  #               "正欲格挡，忽然只见眼前金光一闪，一股劲风已由$N" HIY
  #               "掌中激射而出！\n" NOR;
  # 
  #         me->start_busy(2);
  # 
  #         ap = me->query_skill("strike") + me->query_skill("throwing");
  #         dp = target->query_skill("dodge") + target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 4 + random(ap / 4);
  #                 msg += HIR "$n" HIR "果真始料不及，$N" HIR "那" +
  #                        weapon->query("base_unit") + weapon->name() +
  #                        HIR "正好打在$p" HIR "要穴上，顿时血气上涌，"
  #                        "连退数步！\n" NOR;
  #                 target->receive_damage("qi", damage * 3 / 2, me);
  #                 target->receive_wound("qi", damage, me);
  #             p = (int)target->query("qi") * 100 / (int)target->query("max_qi");
  # 
  #                 COMBAT_D->clear_ahinfo();
  #                 weapon->hit_ob(me, target, me->query("jiali") + 100);
  #                 if (stringp(pmsg = COMBAT_D->query_ahinfo()))
  #                         msg += pmsg;
  #                         msg += "( $n" + eff_status_msg(p) + " )\n";
  #                 message_combatd(msg, me, target);
  # 
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "早料得$P"
  #                        CYN "有此一着，哈哈一笑，斜跳闪开。\n" NOR;
  #                 message_combatd(msg, me, target);
  #         }
  #         me->reset_action();
  #         return 1;
  # }
end
