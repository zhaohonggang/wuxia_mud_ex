defmodule Kantele.Combat.Skills.Performs.XuanyuanArrow.Baibu do
  @moduledoc """
  perform「baibu」（source xuanyuan-arrow/baibu.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "xuanyuan-arrow/baibu"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "xuanyuan-arrow")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          rng: rng
        }
      })

      apply_effect(conn, character)
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
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_other(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "xuanyuan-arrow") < 100 -> {:error, "你的轩辕箭法不够娴熟，不会使用百步穿杨。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 100 -> {:error, "你内力不够了。\n"}
      true -> :ok
    end
  end

  defp check_other(character) do
    # TODO(migrate) 其它门槛（战斗/临时状态/道具等）需人工核对：
    #   {:error, "你现在手中并没有拿着箭，怎么施展百步穿杨？\n"}
    #   {:error, "百步穿杨只能在战斗中对对手使用。\n"}
    #   {:error, "至少要有一支箭你才能施展百步穿杨。\n"}
    :ok

  end

  defp apply_effect(conn, character) do
    # 无条件攻击方效果：消耗/Busy/Apply/暗器数量 + 前置广播
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 80}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}
    # TODO(migrate) 暗器/投掷数量扣减逻辑需人工核对
    #   query_amount()
    conn = Broadcast.publish(conn, "突然间，$N几个筋斗倒翻而去，已在$n数丈之外。$n正待追击，$N忽然转身，好一个「百步穿杨」！
说时迟，那时快，某物已带着破空之声，直射$n面门！", n1: character.name)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "这里没有可供攻击的对手。\n"}
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
    _stats = character.meta.stats
    level = Map.get(data, :level, 0)
    skill = Map.get(data, :skill, 0)
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp
    vitals = character.meta.vitals
    if hit do
          vitals = Vitals.wound(vitals, :qi, (div(skill, 3) + Engine.rand(rng, div(skill, 3))))
    end

    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 80, 2)
    msg = if hit, do: "结果$p反应不及，中了$P一箭！", else: "$n躲过了$N的攻击！"
    result = Messages.interpolate(msg, n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-80"}], "assign_refs": [{"skill", "xuanyuan-arrow"}], "busy_lines": ["me->start_busy(2);"], "level_gates": [{"xuanyuan-arrow", "100"}], "remote_damage": false, "resource_gates": [{"neili", "100"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // baibu.c 百步穿杨
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int skill;
  #         // int n, i;
  #         int my_exp, ob_exp;
  #         string pmsg;
  #         string msg;
  #         object weapon;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("百步穿杨只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("handing")) ||
  #             ! weapon->is_arrow())
  #                 return notify_fail("你现在手中并没有拿着箭，怎么施展百步穿杨？\n");
  # 
  #         if (weapon->query_amount() < 3)
  #                 return notify_fail("至少要有一支箭你才能施展百步穿杨。\n");
  # 
  #         if ((skill = me->query_skill("xuanyuan-arrow", 1)) < 100)
  #                 return notify_fail("你的轩辕箭法不够娴熟，不会使用百步穿杨。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你内力不够了。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         me->add("neili", -80);
  #         weapon->add_amount(-1);
  # 
  #         msg= HIY "突然间，$N" HIY "几个筋斗倒翻而去，已在$n" HIY
  #              "数丈之外。$n" HIY "正待追击，$N" HIY "忽然转身，好一个「百步穿杨」！\n"
  #              HIY "说时迟，那时快，" HIY + weapon->name() + HIY "已带着破空之声，直射$n"
  #              HIY "面门！\n" NOR;
  # 
  #         me->start_busy(2);
  #         my_exp = me->query("combat_exp") + skill * skill / 10 * skill;
  #         ob_exp = target->query("combat_exp");
  #         if (random(my_exp) > ob_exp)
  #         {
  #                 msg += HIR "结果$p" HIR "反应不及，中了$P" + HIR "一箭！\n" NOR;
  #                 target->receive_wound("qi", skill / 3 + random(skill / 3), me);
  #                 COMBAT_D->clear_ahinfo();
  #                 weapon->hit_ob(me, target,
  #                                me->query("jiali") + 120);
  #                 if (stringp(pmsg = COMBAT_D->query_ahinfo()))
  #                         msg += pmsg;
  #                 message_combatd(msg, me, target);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "从容不迫，轻巧的闪过了$P"
  #                        CYN "这一箭。\n" NOR;
  #                 message_combatd(msg, me, target);
  #         }
  # 
  #         me->reset_action();
  #         return 1;
  # }
end
