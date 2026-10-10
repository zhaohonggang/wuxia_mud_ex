defmodule Kantele.Combat.Skills.Performs.WeituoGun.Fumo do
  @moduledoc """
  perform「fumo」（source weituo-gun/fumo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"dp", "force"}], "level_gates": [{"force", "200"}, {"weituo-gun", "140"}], "map_gates": [{"club", "weituo-gun"}], "prepared_gates": [], "resource_gates": [{"neili", "800"}, {"shen", "10000"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你还没有受过高人指点，无法施展「韦陀伏魔」。\n", "「韦陀伏魔」只能在战斗中对对手使用。\n", "你使用的武器不对。\n", "你的内功的修为不够，难以使用这一绝技！\n", "你的韦陀棍法修为不够，目前不能使用韦陀伏魔！\n", "你的真气不够，不能使用韦陀伏魔！\n", "你没有激发韦陀棍法，不能使用韦陀伏魔！\n", "你正气不足，难以理解韦陀伏魔的精髓。\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "0", "dp_formula": "target->query_skill("force")"}, "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "脸色柔和，尽显一派慈祥之意，手中的" + weapon->name() +
      #                 HIY "轻旋，恍惚中显出佛家韦陀神像，\n神光四射，笼罩住$n" + HIY "！\n" NOR", "= CYN "可是$p" CYN "强摄心神，没有被$P"
      #                          CYN "所迷惑，硬生生的架住了$P" CYN "这一招！\n"NOR"], "success": ["= HIR "$n" HIR "平日作恶不少，见了此情此景，心中不禁颤然！\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 60,
      #                                              HIR "结果只听$p" HIR "一声惨叫，被$P"
      #                                              "一下子打中要害，七窍一起生烟，耳鼻都渗出血来！\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-300"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "club"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
