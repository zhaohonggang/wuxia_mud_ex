defmodule Kantele.Combat.Skills.Performs.HuntianBaojian.Sword do
  @moduledoc """
  exert「sword」（source huntian-baojian/sword.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat

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
  defp check_gates(character), do: check_resources(character)

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 50 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 30}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-30"}], "busy_lines": ["me->start_busy(1);"], "remote_damage": false, "resource_gates": [{"neili", "50"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # void dest_sword(object me);
  # 
  # int exert(object me, object target)
  # {
  #         object weapon;
  # 
  #         if (target != me)
  #                 return notify_fail("呵气成剑只能对自己使用。\n");
  # 
  #         if ((int)me->query("neili") < 50)
  #                 return notify_fail("你的内力不够。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail("你手中已经有武器了。\n");
  # 
  #         if (present("jian qi", me))
  #                 return notify_fail("你身上已经有一束剑气了。\n");
  # 
  #         me->add("neili", -30);
  # 
  #         message_combatd(HIW "$N" HIW "食指虚点，指尖顿时生出半尺吞吐不定的"
  #                         "青芒，宛若一束无形剑气。\n" NOR, me);
  # 
  #         weapon = new("/clone/weapon/jianqi");
  #         weapon->move(me);
  #         weapon->wield();
  # 
  #         me->start_call_out((: call_other, __FILE__, "dest_sword",
  #                               me :), 50);
  # 
  #         if (me->is_fighting())
  #                 me->start_busy(1);
  # 
  #         return 1;
  # }
  # 
  # void dest_sword(object me)
  # {
  #         object weapon;
  # 
  #         if (objectp(weapon = me->query_temp("weapon"))
  #            && (string)weapon->query("skill_type") == "sword"
  #            && (string)weapon->query("id") == "jian qi")
  #         {
  #                 if (me->is_fighting())
  #                         me->start_call_out((: call_other, __FILE__, "dest_sword",
  #                                               me :), 2);
  #                 else
  #                         destruct(weapon);
  #         }
  # }
end
