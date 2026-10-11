defmodule Kantele.Combat.Skills.Performs.ShedaoQigong.Chang3 do
  @moduledoc """
  perform「chang3」（source shedao-qigong/chang3.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "shedao-qigong/chang3"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "shedao-qigong")

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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "shedao-qigong") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
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

  # TODO(migrate) 目标侧结算：命中/闪避/伤害公式与文案需按原始源码（见文末）补齐。
  #   target->receive_damage("jing", damage)  # UNSUPPORTED: unknown ident damage
  #   target->receive_damage("qi", damage)  # UNSUPPORTED: unknown ident damage
  #   target->receive_wound("jing", damage / 8)  # UNSUPPORTED: unknown ident damage
  #   target->receive_wound("qi", damage / 8)  # UNSUPPORTED: unknown ident damage

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"busy_lines": ["me->start_busy(1 + random(5));"], "level_gates": [{"shedao-qigong", "100"}], "remote_damage": false, "resource_gates": [{"neili", "500"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // 唱仙法吼字决
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //    string msg;
  #         int neili, damage;
  # //    int i;
  # 
  #     if (! target ) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("唱仙法吼字决只能在战斗中对对手使用。\n");
  # 
  #     if ((int)me->query_skill("shedao-qigong", 1) < 100)
  #         return notify_fail("你的蛇岛奇功不够娴熟，不会使用唱仙法吼字决。\n");
  # 
  #     if (environment(me)->query("no_fight"))
  #         return notify_fail("在这里不能攻击他人。\n");
  # 
  #     if ((int)me->query("neili") < 500)
  #         return notify_fail("你已经精疲力竭，真气不够了。\n");
  # 
  #     neili = me->query("max_neili");
  # 
  #     me->add("neili", -(300 + random(200)));
  #     me->receive_damage("qi", 10);
  # 
  #     me->start_busy(1 + random(5));
  # 
  #     message_combatd(HIY "$N" HIY "深深地吸一囗气，忽然仰天长啸，高"
  #                         "声狂叫：不死神龙，唯我不败！\n" NOR, me);
  # 
  #         if (neili / 2 + random(neili / 2) < (int)target->query("max_neili"))
  #         return notify_fail("敌人的内力不逊于你，伤不了！\n");
  # 
  #     damage = (neili - (int)target->query("max_neili")) / 10;
  #     if (damage > 0)
  #         {
  #         target->receive_damage("jing", damage, me);
  #         target->receive_damage("qi", damage, me);
  #         target->receive_wound("jing", damage / 8, me);
  #         target->receive_wound("qi", damage / 8, me);
  #         message_combatd(HIR "$N" HIR "只觉脑中一阵剧痛，金星乱"
  #                                 "冒，犹如有万条金龙在眼前舞动。\n" NOR, target);
  #     }
  #         me->want_kill(target);
  #         me->kill_ob(target);
  #     return 1;
  # }
end
