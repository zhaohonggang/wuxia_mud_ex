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

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // luohan-gun perform 罗汉棍阵
      # 
      # #include <ansi.h>
      # 
      # #define SHIBA HIY "【十八罗汉棍阵】" NOR
      # 
      # #define ME  "你现在不能使用" + SHIBA + "。\n"
      # #define TAR  "对方现在不能使用" + SHIBA + "。\n"
      # 
      # int check_fight(object me, object target, int amount);
      # private int remove_effect(object me, object target, int amount);
      # 
      # int perform(object me, object target)
      # {
      #         object *enemy;
      #         int i,j,k,amount;
      #         object wep1, wep2;
      #         wep1 = me->query_temp("weapon");
      # 
      #         if( !target || target == me) return notify_fail("你要和谁组成棍阵?\n");
      # 
      #         if (me->query_temp("gunzhen")) return notify_fail(ME);
      #         if (target->query_temp("gunzhen")) return notify_fail(TAR);
      #         if (me->query("jingli") < 200) return notify_fail(ME);
      #         if (target->query("jingli") < 200) return notify_fail(TAR);
      #         if (me->query("neili") < 1500) return notify_fail(ME);
      #         if (target->query("neili") < 1500) return notify_fail(TAR);
      #         if (!me->is_fighting()) return notify_fail( SHIBA "只能在战斗中使用。\n");
      #         if (me->is_fighting(target)) return notify_fail("你已经在和对方打架，使用" + SHIBA + "作什么?\n");
      #         if( (int)me->query_skill("luohan-gun", 1) < 120 ) return notify_fail(ME);
      #         if( (int)me->query_skill("club", 1) < 120 ) return notify_fail(ME);
      #         if (!wep1 || wep1->query("skill_type") != "club"
      #         || me->query_skill_mapped("club") != "luohan-gun")
      #                 return notify_fail(ME);
      #         
      #         enemy = me->query_enemy();
      #         k = sizeof(enemy);
      #         while (k--)
      #         if (target->is_fighting(enemy[k])) break;
      #         if (k<0) return notify_fail(target->name()+"并没有和你的对手在交战。\n");
      # 
      #         if( (int)target->query_skill("luohan-gun", 1) < 120 )
      #                 return notify_fail(TAR);
      #         if( (int)target->query_skill("club", 1) < 120 )
      #                 return notify_fail(TAR);
      #         wep2 = target->query_temp("weapon");
      #         if (target->is_busy() || !wep2 || wep2->query("skill_type") != "club"
      #         || target->query_skill_mapped("club") != "luohan-gun")
      #                 return notify_fail(TAR);
      #                 
      # 
      #         message_vision(HIY "\n只见他们几人，动作协调，阵行严谨，攻守一体，"+
      #                            "一招一式，都似发自同一人，威力大增。"+
      #                            "$n不由看的呆了......\n" NOR, me, target);
      #         me->set_temp("gunzhen", 1);
      #         target->set_temp("bunzhen", 1);
      #         me->receive_damage("jingli", 100);
      #         target->receive_damage("jingli", 100);
      #         me->receive_damage("neili", 300);
      #         target->receive_damage("neili", 300);
      #         me->start_busy(1);
      #         target->start_busy(1);
      #         i = (int)me->query_skill("luohan-gun", 1);
      #         j = (int)target->query_skill("luohan-gun", 1);
      #         amount = ((i + j)/10 + (int)me->query_str() + (int)target->query_str())/5;
      #         if( amount > 20 ) amount = 20;
      #         me->add_temp("apply/dexerity", amount);
      #         me->add_temp("apply/strength", amount);
      #         target->add_temp("apply/dexerity", amount);
      #         target->add_temp("apply/strength", amount);
      #         enemy[k]->start_busy(amount/3);
      #         check_fight(me, target, amount);
      #         return 1;
      # }
      # 
      # int check_fight(object me, object target, int amount)
      # {  
      #         object wep1, wep2;
      #         if(!me && !target) return 0;
      #         if(!me && target){
      #            target->add_temp("apply/dexerity", -amount);
      #            target->add_temp("apply/strength", -amount);
      #            target->delete_temp("gunzhen");
      #            return 0;
      #         }
      #         if( me && !target){
      #            me->add_temp("apply/dexerity", -amount);
      #            me->add_temp("apply/strength", -amount);
      #            me->delete_temp("gunzhen");
      #            return 0;
      #         }
      #         wep1 = me->query_temp("weapon");
      #         wep2 = target->query_temp("weapon");
      #         if(!me->is_fighting()
      #          || !living(me)
      #          || me->is_ghost()
      #          || !wep1
      #          || !target->is_fighting()
      #          || !living(target)
      #          || target->is_ghost() 
      #          || !wep2
      #          || me->query_skill_mapped("club") != "luohan-gun" 
      #          || target->query_skill_mapped("club") != "luohan-gun"
      #          || environment(me) != environment(target))
      #               remove_effect(me, target, amount);
      #         else {
      #               call_out("check_fight", 1, me, target, amount);
      #         }
      #         return 1;
      # }
      # 
      # private int remove_effect(object me, object target, int amount)
      # {
      #         if(living(me)
      #          && !me->is_ghost()
      #          && living(target)
      #          && !target->is_ghost())
      #            message_vision(HIY "\n各僧众将阵法施展完毕，各自收招。\n" NOR, me, target);
      # 
      #         me->add_temp("apply/dexerity", -amount);
      #         me->add_temp("apply/strength", -amount);
      #         target->add_temp("apply/dexerity", -amount);
      #         target->add_temp("apply/strength", -amount);
      #         me->delete_temp("gunzhen");
      #         target->delete_temp("gunzhen");
      #         return 0;
      # }
end
