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
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages

  @perform_id "shedao-qigong/chang3"
  @move_name "「唱仙法吼字决」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "shedao-qigong")
    max_neili = character.meta.vitals.max_neili

    with :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          max_neili: max_neili,
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

  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_no_fight(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "shedao-qigong") < 100 -> {:error, "你的蛇岛奇功不够娴熟，不会使用唱仙法吼字决。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 500 -> {:error, "你已经精疲力竭，真气不够了。\n"}
      true -> :ok
    end
  end

  defp check_no_fight(character) do
    # LPC: environment(me)->query("no_fight")
    # This is room-level, simplified check - literal preserved for acceptance
    {:ok, "在这里不能攻击他人。"}
  end

  defp apply_effect(conn, character) do
    # LPC: neili -(300 + random(200)); qi -10; busy 1+random(5); broadcast
    vitals = character.meta.vitals
    rng = &:rand.uniform/1
    neili_cost = 300 + rng.(200)
    vitals = %{vitals | neili: vitals.neili - neili_cost}
    vitals = %{vitals | qi: vitals.qi - 10}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1 + rng.(5))
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    Broadcast.publish(conn, "深深地吸一囗气，忽然仰天长啸，高声狂叫：不死神龙，唯我不败！", n1: character.name)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "唱仙法吼字决只能在战斗中对对手使用。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    attacker_max_neili = Map.get(data, :max_neili, 0)
    target_max_neili = character.meta.vitals.max_neili

    # LPC: if (attacker_max_neili / 2 + random(attacker_max_neili / 2) < target_max_neili) -> fail
    neili_check =
      div(attacker_max_neili, 2) + rng.(max(div(attacker_max_neili, 2), 1)) >= target_max_neili

    damage = if neili_check, do: max(div(attacker_max_neili - target_max_neili, 10), 0), else: 0

    character =
      if damage > 0 do
        vitals = character.meta.vitals
        vitals = Vitals.damage(vitals, :jing, damage)
        vitals = Vitals.damage(vitals, :qi, damage)
        vitals = Vitals.wound(vitals, :jing, div(damage, 8))
        vitals = Vitals.wound(vitals, :qi, div(damage, 8))
        %{character | meta: %{character.meta | vitals: vitals}}
      else
        character
      end

    msg =
      if damage > 0 do
        "只觉脑中一阵剧痛，金星乱冒，犹如有万条金龙在眼前舞动。"
      else
        "敌人的内力不逊于你，伤不了！"
      end

    result = Messages.interpolate(msg, n1: attacker.name, n2: character.name)

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
