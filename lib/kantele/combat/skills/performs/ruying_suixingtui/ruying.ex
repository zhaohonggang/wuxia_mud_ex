defmodule Kantele.Combat.Skills.Performs.RuyingSuixingtui.Ruying do
  @moduledoc """
  perform「ruying」（source ruying-suixingtui/ruying.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"i", "ruying-suixingtui"}], "level_gates": [{"force", "160"}, {"ruying-suixingtui", "160"}], "map_gates": [{"unarmed", "ruying-suixingtui"}], "prepared_gates": [{"unarmed", "ruying-suixingtui"}], "resource_gates": [{"max_neili", "2000"}, {"neili", "700"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这样的功能。\n", "「如影随形」只能在战斗中对对手使用。\n", "使用「如影随形」时双手必须空着！\n", "你的如影随形腿不够娴熟，不会使用「如影随形」。\n", "你的内功等级不够，不能使用「如影随形」。\n", "你的身法不够强，不能使用「如影随形」。\n", "你现在无法使用「如影随形」进行攻击。\n", "你的内力修为太弱，不能使用「如影随形」！\n", "你现在内力太少，不能使用「如影随形」。\n"], "color_codes": ["HIR", "HIY", "NOR", "YEL"], "combat_messages": %{"fail": [], "other": ["YEL "\n你猛吸一口真气，体内劲力瞬时爆发！\n" NOR", "HIY "$N忽然跃起，左脚一勾一弹，霎时之间踢出一招「如」字诀的穿心腿，直袭$n前胸！"NOR", "HIY "紧接着$N左腿勾回，将腰身一扭，那右腿的一招「影」字诀便紧随而至，飞向$n！"NOR", "HIY"只见$N右脚劲力未消，便凌空一转，左腿顺势扫出一招「随」字诀，如影而至！"NOR", "HIY"半空中$N脚未后撤，已经运起「形」字诀，内劲直透脚尖，在$n胸腹处连点了数十下！"NOR", "HIY"$N忽然跃起，左脚一勾一弹，霎时之间踢出一招「如」字诀的穿心腿，直袭$n前胸！"NOR", "HIY"紧接着$N左腿勾回，将腰身一扭，那右腿的一招「影」字诀便紧随而至，飞向$n！"NOR", "HIY"只见$N右脚劲力未消，便凌空一转，左腿顺势扫出一招「随」字诀，如影而至！"NOR", "HIY"半空中$N脚未后撤，已经运起「形」字诀，内劲直透脚尖，在$n胸腹处连点了数十下！"NOR", "YEL "\n你连环飞腿使完，全身一转，稳稳落在地上。\n" NOR"], "success": ["HIR"这时$N双臂展动，带起一股强烈的旋风，双腿霎时齐并，「如影随形」一击重炮轰在$n胸膛之上！"NOR"]}, "resource_adds": [{"neili", "-400"}, {"neili", "-500"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-400"}, {"neili", "-500"}], "affect_by": [], "apply_adds": ["attack", "damage", "dexerity", "strength"], "busy_lines": ["me->start_busy(2+random(2));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2+random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
