defmodule Kantele.Combat.Skills.Performs.ZuiGun.Zuida do
  @moduledoc """
  perform「zuida」（source zui-gun/zuida.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "zui-gun/zuida"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "zui-gun")
    skill = Stats.skill(stats, "zui-gun")

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
         :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "club") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "force") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "hunyuan-yiqi" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "force") != "luohan-fumogong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "force") != "yijinjing" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 150}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
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
    _stats = character.meta.stats
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 150, 2)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
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
