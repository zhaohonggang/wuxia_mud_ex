defmodule Kantele.Combat.Skills.Performs.LuohanGun.Shibaluohan do
  @moduledoc """
  perform「shibaluohan」（source luohan-gun/shibaluohan.c，由 translate_perform.py 生成，inherit ?）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "luohan-gun/shibaluohan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "luohan-gun")
    amount = 20

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
      Stats.skill(stats, "club") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "luohan-gun") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "club") != "luohan-gun" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.jingli < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 1500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

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
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    vitals = character.meta.vitals
        vitals = Vitals.damage(vitals, :jingli, 100)
        vitals = Vitals.damage(vitals, :neili, 300)
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 0, 1)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"apply_adds": ["dexerity", "strength"], "assign_refs": [{"i", "luohan-gun"}, {"j", "luohan-gun"}], "busy_lines": ["if (target->is_busy() || !wep2 || wep2->query("skill_type") != "club"", "me->start_busy(1);", "target->start_busy(1);", "enemy[k]->start_busy(amount/3);"], "level_gates": [{"club", "120"}, {"luohan-gun", "120"}], "map_gates": [{"club", "luohan-gun"}], "remote_damage": false, "resource_gates": [{"jingli", "200"}, {"neili", "1500"}], "temp_set": ["bunzhen", "gunzhen"], "var_gates": [{"k", "0"}]}

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
