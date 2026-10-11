defmodule Kantele.Combat.Skills.Performs.ZixiaShengong.Ziqi do
  @moduledoc """
  exert「ziqi」（source zixia-shengong/ziqi.c，由 translate_perform.py 生成，inherit F_SSERVER）

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
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 3)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}], "apply_adds": ["damage", "sword"], "assign_refs": [{"skill", "zixia-shengong"}], "busy_lines": ["if( me->is_fighting() ) me->start_busy(3);"], "remote_damage": false, "resource_gates": [{"neili", "200"}], "temp_set": ["ziqi"], "var_gates": [{"skill", "150"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // from NT MudLIB
  # // ziqi.c 紫气东来
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # void remove_effect(object me, int amount);
  # 
  # int exert(object me, object target)
  # {
  # //      string msg;
  # //      mapping buff,data;
  #         int /*d_count,count,*/ qi, maxqi, skill;
  #         object weapon = me->query_temp("weapon");
  #         skill = me->query_skill("zixia-shengong", 1);
  # 
  #         if((int)me->query_temp("ziqi"))
  #                 return notify_fail(HIG"你已经在运起紫气东来了。\n");
  # 
  #         if((int)me->query("neili") < 200 )
  #                 return notify_fail("你的内力还不够！\n");
  # 
  #         if(skill < 150)
  #                 return notify_fail("你的紫霞神功的修为不够，不能使用紫气东来! \n");
  # 
  #         // 必须有兵器。加兵器威力
  #         if ( ! weapon || weapon->query("skill_type") != "sword" )
  #                 return notify_fail("你没有剑.怎么用紫气东来呀? \n");
  # 
  #         qi = me->query("qi");
  #         maxqi = me->query("max_qi");
  # 
  #         message_combatd(MAG "$N" MAG "猛吸一口气，脸上紫气大盛！手中的兵器隐隐透出一层紫光。。。\n" NOR, me);
  # 
  #         if( qi > (maxqi * 0.4) )
  #         {
  #                 me->add_temp("apply/damage", skill / 10);
  #                 me->add_temp("apply/sword", skill / 10);
  #                 me->set_temp("ziqi", 1);
  #                 me->start_call_out((: call_other, __FILE__, "remove_effect", me, skill / 10 :), skill);
  #                 me->add("neili", -200);
  #         }
  #         else
  #         {
  #                 message_combatd(HIR "$N" HIR "拼尽毕生功力想提起紫气东来，但自己受伤太重，没能成功!\n" NOR, me);
  #         }
  # 
  #         if( me->is_fighting() ) me->start_busy(3);
  #         return 1;
  # }
  # 
  # void remove_effect(object me, int amount)
  # {
  #         if (me->query_temp("ziqi"))
  #         {
  #                 me->add_temp("apply/damage", -amount);
  #                 me->add_temp("apply/sword", -amount);
  #                 me->delete_temp("ziqi");
  #                 tell_object(me, "你的紫气东来运行完毕，紫气渐渐隐去。\n");
  #         }
  # }
end
