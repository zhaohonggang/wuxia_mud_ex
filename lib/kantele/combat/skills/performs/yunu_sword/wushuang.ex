defmodule Kantele.Combat.Skills.Performs.YunuSword.Wushuang do
  @moduledoc """
  perform「wushuang」（source yunu-sword/wushuang.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

  TODO(migrate): 样本人工校对后，把以下门槛/语义写进 check_* 与 apply_effect。
  以上注释行（TODO(migrate)）校对完成后删除。
  """

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView

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

  # TODO(migrate) 提取器门槛事实（核对后替换为真实查法）：
      #   %{"assign_refs": [{"damage", "sword"}], "level_gates": [{"force", "120"}, {"yunu-sword", "80"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["无双无对只能对战斗中的对手使用。\n", "你使用的武器不对。\n", "你的玉女金针十三剑不够娴熟，不会使用「无双无对」。\n", "你的内功不够娴熟，不会使用「无双无对」。\n", "你的内力不够。\n", "你已经在运功中了。\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "双手握起" + weapon->name() + HIY
      #                 "，剑芒暴长，一式「无双无对」，驭剑猛烈绝伦地往$n"
      #                 HIY "冲刺！\n"NOR", "= CYN "可是$p" CYN "看破了$P"
      #                          CYN "的企图，向旁一跃，躲了开去。" NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 45,
      #                                              HIR "$n" HIR "看到$N" HIR "这一剑妙到毫巅，全然无"
      #                                              "法抵挡，一愣神之间已经被这一剑刺得鲜血飞溅！" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("sword")"}, "resource_adds": [{"neili", "-250"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-250"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
