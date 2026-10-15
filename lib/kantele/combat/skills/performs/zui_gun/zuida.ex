defmodule Kantele.Combat.Skills.Performs.ZuiGun.Zuida do
  @moduledoc """
  perform「八仙醉打」（source zui-gun/zuida.c，由 translate_perform.py 生成，inherit F_SSERVER）

  自增益绝招：临时提升臂力/身法（skill/3 秒后由 remove_effect 回收），
  耗 150 内力，战斗中忙乱 2 轮。原提取器生成的攻击型骨架（perform-incoming
  事件 + resolve_incoming）与本招无关（.c 无攻击结算），已按 ziqi 先例
  重构为 run → gates → apply_effect。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.Stats
  alias Kalevala.Event

  @key "zg_zuida"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_gates(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_mapped(character),
         :ok <- check_weapon(character),
         :ok <- check_not_active(character),
         :ok <- check_no_powerup(character),
         :ok <- check_levels(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  # LPC: if ((me->query_skill_mapped("force") != "hunyuan-yiqi") &&
  #          (me->query_skill_mapped("force") != "yijinjing") &&
  #          (me->query_skill_mapped("force") != "luohan-fumogong"))
  #         return notify_fail("你现在没有激发少林内功为内功，难以施展「八仙醉打」。\n");
  defp check_mapped(character) do
    mapped = Stats.mapped(character.meta.stats, "force")

    cond do
      mapped != "hunyuan-yiqi" and mapped != "yijinjing" and mapped != "luohan-fumogong" ->
        {:error, "你现在没有激发少林内功为内功，难以施展「八仙醉打」。\n"}

      true -> :ok
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #         (string)weapon->query("skill_type") != "club")
  #         return notify_fail("你使用的武器不对。\n");
  defp check_weapon(character) do
    case Combat.weapon(character.meta.combat) do
      %{skill_type: "club"} -> :ok
      _ -> {:error, "你使用的武器不对。\n"}
    end
  end

  # LPC: if ((int)me->query_temp("zg_zuida"))
  #         return notify_fail("你已经在运功中了。\n");
  defp check_not_active(character) do
    if Combat.buff_active?(character.meta.combat, @key) do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_temp("powerup"))
  #         return notify_fail("你已经运起内功提升战力了，不能再使用「八仙醉打」。\n");
  defp check_no_powerup(character) do
    if Combat.buff_active?(character.meta.combat, "powerup") do
      {:error, "你已经运起内功提升战力了，不能再使用「八仙醉打」。\n"}
    else
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      stats.str < 25 -> {:error, "你现在的臂力不够，目前不能使用「八仙醉打」！\n"}
      Stats.skill(stats, "force") < 150 -> {:error, "你的内功火候不够，难以施展「八仙醉打」！\n"}
      Stats.skill(stats, "club") < 100 -> {:error, "你的棍法修为不够，不会使用「八仙醉打」！\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 500 -> {:error, "你的真气不足！\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # LPC: msg = HIY "$N" HIY "使出少林醉棍的绝技「八仙醉打」，臂"
    #               "力陡然增加, 身法陡然加快！\n" NOR;
    #      message_combatd(msg, me, target);
    conn =
      Broadcast.publish(
        conn,
        "$N使出少林醉棍的绝技「八仙醉打」，臂力陡然增加, 身法陡然加快！\n",
        n1: character.name
      )

    # LPC: skill = me->query_skill("zui-gun",1);
    #      cnt =(int)( (int)me->query_condition("drunk") / 3);
    #      count = me->query("str") * random(cnt + 2);
    #      count1 = me->query("dex") * random(cnt + 2);
    #      me->add_temp("str", count); me->add_temp("dex", count1);
    #      me->set_temp("zg_zuida", 1);
    #      me->start_call_out(remove_effect, skill / 3);
    #      me->add("neili", -150);
    #      if (me->is_fighting()) me->start_busy(2);
    skill = Stats.skill(character.meta.stats, "zui-gun")

    # LPC: add_temp("str"/"dex", count/count1) —— 本引擎未建模 str/dex 临时属性，
    # 故 buff 无数值加成，仅保留状态与到期回收（与 shexing-lifan/guiyuan 取舍一致）。
    buff = %Buff{key: @key, applies: %{}, duration: div(skill, 3)}

    # remove_effect：skill/3 秒后回收状态并提示（combat/buff-expire 由框架处理）
    Process.send_after(
      self(),
      %Event{
        from_pid: self(),
        topic: "combat/buff-expire",
        data: %{
          key: @key,
          applies: buff.applies,
          message: "你的「八仙醉打」运功完毕，将内力收回丹田。\n"
        }
      },
      div(skill, 3) * 1000
    )

    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 150}

    combat = Combat.add_buff(character.meta.combat, buff)

    # LPC: if (me->is_fighting()) me->start_busy(2);
    combat =
      if Combat.fighting?(combat),
        do: Combat.start_busy(combat, 2),
        else: combat

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-150"}], "assign_refs": [{"skill", "zui-gun"}], "busy_lines": ["me->start_busy(2);"], "level_gates": [{"club", "100"}, {"force", "150"}], "map_gates": [{"force", "hunyuan-yiqi"}, {"force", "luohan-fumogong"}, {"force", "yijinjing"}], "remote_damage": false, "resource_gates": [{"neili", "500"}], "temp_set": ["zg_zuida"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // zuida.c 少林醉棍 八仙醉打
  #
  # #include <ansi.h>
  #
  # inherit F_SSERVER;
  #
  # inherit F_CLEAN_UP;
  #
  # void remove_effect(object me, int amount, int amount1);
  #
  # int perform(object me, object target)
  # {
  #     object weapon;
  #       string msg;
  #     int count, count1, cnt, skill;
  #
  #     //if (! me->is_fighting())
  #     //        return notify_fail("「八仙醉打」只能在战斗中使用。\n");
  #     if ((me->query_skill_mapped("force") != "hunyuan-yiqi") && (me->query_skill_mapped("force") != "yijinjing") && (me->query_skill_mapped("force") != "luohan-fumogong"))
  #                 return notify_fail("你现在没有激发少林内功为内功，难以施展「八仙醉打」。\n");
  #
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "club")
  #         return notify_fail("你使用的武器不对。\n");
  #
  #     if ((int)me->query_temp("zg_zuida"))
  #         return notify_fail("你已经在运功中了。\n");
  #
  #     if ((int)me->query_temp("powerup"))
  #         return notify_fail("你已经运起内功提升战力了，不能再使用「八仙醉打」。\n");
  #
  #     if ((int)me->query_str() < 25)
  #         return notify_fail("你现在的臂力不够，目前不能使用「八仙醉打」！\n");
  #
  #     if ((int)me->query_skill("force") < 150)
  #         return notify_fail("你的内功火候不够，难以施展「八仙醉打」！\n");
  #
  #     if ((int)me->query_skill("club") < 100)
  #         return notify_fail("你的棍法修为不够，不会使用「八仙醉打」！\n");
  #
  #     if ((int)me->query("neili") < 500)
  #         return notify_fail("你的真气不足！\n");
  #
  #     msg = HIY "$N" HIY "使出少林醉棍的绝技「八仙醉打」，臂"
  #               "力陡然增加, 身法陡然加快！\n" NOR;
  #
  #        message_combatd(msg, me, target);
  #     skill = me->query_skill("zui-gun",1);
  #     cnt =(int)( (int)me->query_condition("drunk") / 3);
  #     count = me->query("str") * random(cnt + 2);
  #     count1 = me->query("dex") * random(cnt + 2);
  #
  #     me->add_temp("str", count);
  #     me->add_temp("dex", count1);
  #     me->set_temp("zg_zuida", 1);
  #
  #     me->start_call_out((: call_other, __FILE__, "remove_effect",
  #                            me, count, count1 :), skill / 3);
  #
  #     me->add("neili", -150);
  #     if (me->is_fighting())
  #       me->start_busy(2);
  #        return 1;
  # }
  #
  # void remove_effect(object me, int amount, int amount1)
  # {
  #     if ((int)me->query_temp("zg_zuida"))
  #     {
  #         me->add_temp("str", -amount);
  #         me->add_temp("dex", -amount1);
  #         me->delete_temp("zg_zuida");
  #         tell_object(me, "你的「八仙醉打」运功完毕，将内力收回丹田。\n");
  #     }
  # }
end
