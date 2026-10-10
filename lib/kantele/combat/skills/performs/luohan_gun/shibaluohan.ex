defmodule Kantele.Combat.Skills.Performs.LuohanGun.Shibaluohan do
  @moduledoc """
  perform「shibaluohan」（source luohan-gun/shibaluohan.c，由 translate_perform.py 骨架生成，inherit ?）

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
      #   %{"assign_refs": [{"i", "luohan-gun"}, {"j", "luohan-gun"}], "level_gates": [{"club", "120"}, {"luohan-gun", "120"}], "map_gates": [{"club", "luohan-gun"}], "prepared_gates": [], "resource_gates": [{"jingli", "200"}, {"neili", "1500"}], "var_gates": [{"k", "0"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你要和谁组成棍阵?\n", "你已经在和对方打架，使用"], "buff_delete": ["gunzhen"], "callback_functions": [%{"body": "object wep1, wep2;
      #           if(!me && !target) return 0;
      #           if(!me && target){
      #              target->add_temp("apply/dexerity", -amount);
      #              target->add_temp("apply/strength", -amount);
      #        ", "name": "check_fight", "params": "object me, object target, int amount", "return_type": "int"}, %{"body": "if(living(me)
      #            && !me->is_ghost()
      #            && living(target)
      #            && !target->is_ghost())
      #              message_vision(HIY "\n各僧众将阵法施展完毕，各自收招。\n" NOR, me, target);
      #   
      #           me->add_temp("appl", "name": "remove_effect", "params": "object me, object target, int amount", "return_type": "int"}], "color_codes": ["HIB", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "receive_damage_calls": [%{"formula": "100", "kind": "damage", "part": "jingli", "source": None}, %{"formula": "100", "kind": "damage", "part": "jingli", "source": None}, %{"formula": "300", "kind": "damage", "part": "neili", "source": None}, %{"formula": "300", "kind": "damage", "part": "neili", "source": None}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "club"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": ["dexerity", "strength"], "busy_lines": ["if (target->is_busy() || !wep2 || wep2->query("skill_type") != "club"", "me->start_busy(1);", "target->start_busy(1);", "enemy[k]->start_busy(amount/3);"], "remote_damage": false, "set_flags": [], "temp_set": ["bunzhen", "gunzhen"]}
      #   - if (target->is_busy() || !wep2 || wep2->query("skill_type") != "club"
      #   - me->start_busy(1);
      #   - target->start_busy(1);
      #   - enemy[k]->start_busy(amount/3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
