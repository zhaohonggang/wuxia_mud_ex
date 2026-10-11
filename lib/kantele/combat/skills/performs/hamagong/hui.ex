defmodule Kantele.Combat.Skills.Performs.Hamagong.Hui do
  @moduledoc """
  exert「hui」（source hamagong/hui.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView

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

  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: 0}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"apply_adds": ["armor", "dispel_poison", "dodge", "parry"], "remote_damage": false, "set_flags": [{"neili", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // hui.c 蛤蟆功回息
  # 
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # void remove_effect(object me, int a_amount);
  # 
  # int exert(object me, object target)
  # {
  #         int skill;
  #         string msg;
  # 
  #         if (! (skill = me->query_temp("hmg_dzjm")))
  #                 return notify_fail("你并没有倒转经脉啊。\n");
  # 
  #         msg = HIB "$N" HIB "缓缓吐出一口气，脸色变了变，阴阳不定。\n" NOR;
  #         message_combatd(msg, me);
  # 
  #         me->add_temp("apply/dodge", -skill / 3);
  #         me->add_temp("apply/parry", -skill / 3);
  #         me->add_temp("apply/armor", -skill / 2);
  #         me->add_temp("apply/dispel_poison", -skill / 2);
  #         me->delete_temp("hmg_dzjm");
  # 
  #         me->set("neili", 0);
  #         return 1;
  # }
end
