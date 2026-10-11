defmodule Kantele.Combat.Skills.Performs.BlueseaForce.Xuan do
  @moduledoc """
  perform「xuan」（source bluesea-force/xuan.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "bluesea-force/xuan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "bluesea-force")
    i = 5
    count = 0

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
      Stats.skill(stats, "bluesea-force") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "bluesea-force" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
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
  #   %{"apply_adds": ["attack"], "assign_refs": [{"count", "bluesea-force"}, {"lvl", "bluesea-force"}], "busy_lines": ["if (i > 4 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(7));"], "level_gates": [{"bluesea-force", "150"}], "map_gates": [{"strike", "bluesea-force"}], "prepared_gates": [{"strike", "bluesea-force"}], "remote_damage": false, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // yong.c 玄黄连环掌
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int count;
  #         int lvl;
  #         int i;
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("玄黄连环掌只能对战斗中的对手使用。\n");
  # 
  #     if (me->query("neili") < 200)
  #         return notify_fail("你的真气不够，无法施展玄黄连环掌！\n");
  # 
  #     if ((lvl = me->query_skill("bluesea-force", 1)) < 150)
  #         return notify_fail("你的南海玄功火候不够，无法施展玄黄连环掌！\n");
  # 
  #         if (me->query_skill_mapped("strike") != "bluesea-force")
  #                 return notify_fail("你没有激发南海玄功为掌法，无法施展玄黄连环掌！\n");
  # 
  #         if (me->query_skill_prepared("strike") != "bluesea-force")
  #                 return notify_fail("你没有准备好使用南海玄功，无法施展玄黄连环掌！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIC "$N" HIC "轻轻划了个圈子，身形忽然变快，合数招为一击攻向$n"
  #               HIC "！\n" NOR;
  #         i = 5;
  #         if (lvl / 2 + random(lvl) > (int)target->query_skill("force") * 2 / 3)
  #         {
  #                 msg += HIY "内力激荡之下，$n" HIY "登时觉得呼吸"
  #                        "不畅，浑身有如重压，万分难受，只见$N"
  #                        HIY "一掌接一掌的攻到，有如海浪。\n" NOR;
  #                 count = me->query_skill("bluesea-force", 1) / 5;
  #                 me->add_temp("apply/attack", count);
  #                 i += random(5);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "见来掌奇快，只好振作精神勉力抵挡。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #     message_combatd(msg, me, target);
  #     me->add("neili", -i * 20);
  # 
  #         while (i--)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (i > 4 && ! target->is_busy())
  #                         target->start_busy(1);
  #             COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -count);
  #     me->start_busy(1 + random(7));
  #     return 1;
  # }
end
