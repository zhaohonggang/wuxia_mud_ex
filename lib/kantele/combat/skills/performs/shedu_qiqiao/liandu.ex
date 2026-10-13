defmodule Kantele.Combat.Skills.Performs.SheduQiqiao.Liandu do
  @moduledoc """
  perform「liandu」（source shedu-qiqiao/liandu.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Combat.Messages

  @blank ""

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with {:ok, target} <- find_snake_target(character),
         :ok <- check_gates(character, target) do
      apply_effect(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp find_snake_target(character) do
    room_id = character.room_id

    room_chars =
      Kantele.Communication.subscribers("rooms:#{room_id}")
      |> Enum.map(fn {_channel_name, pid, _options} -> pid end)

    # Find first snake NPC in room (simplified: check for snake_poison temp or aliases)
    snake_pid =
      Enum.find(room_chars, fn pid ->
        pid != self() and is_snake_npc?(pid)
      end)

    case snake_pid do
      nil ->
        {:error, "你要取哪条蛇的毒液练药？\n"}

      pid ->
        {:ok, safe_state(pid)}
    end
  end

  defp is_snake_npc?(pid) when is_pid(pid) do
    # Simplified check - in reality would check NPC metadata for snake type
    case safe_state(pid) do
      %{meta: %{temp: temp}} when is_map(temp) -> Map.has_key?(temp, "snake_poison")
      _ -> false
    end
  end

  defp safe_state(pid) when is_pid(pid) do
    :sys.get_state(pid)
  catch
    _, _ -> %{pid: pid, meta: %{}}
  end

  defp check_gates(character, target) do
    with :ok <- check_snake_type(target),
         :ok <- check_not_living(target),
         :ok <- check_levels(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_snake_type(target) do
    # LPC: target->is_snake()
    # Simplified: check for snake_poison in temp
    case target.meta.temp do
      %{"snake_poison" => _} -> :ok
      _ -> {:error, "看清楚些，那不是蛇，你瞎搞什么？\n"}
    end
  end

  defp check_not_living(target) do
    # LPC: !living(target)
    if dead?(target) do
      :ok
    else
      {:error, "那条蛇还精神着呢，你找死啊。\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}) when dead == true, do: true
  defp dead?(_), do: false

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "shedu-qiqiao") < 80 ->
        {:error, "你的蛇毒奇巧还不够娴熟，不能炼制毒药。\n"}

      # hamagong gate commented out in LPC
      # Stats.skill(stats, "hamagong") < 80 ->
      #   {:error, "你的蛤蟆功的修为不够，不能炼制毒药。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "你现在的内力不够！\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character, target) do
    # Cost: neili -50, busy random(3)
    vitals = character.meta.vitals

    character = %{
      character
      | meta: Map.put(character.meta, :vitals, %{vitals | neili: vitals.neili - 50})
    }

    _busy_time = :rand.uniform(3)

    # LPC: msg = HIC "\n$N" HIC "伸出双指，捏住" + target->name() +
    #               HIC "的嘴巴，以内力迫出毒液练药。\n" NOR;
    # Split target name with @blank for Messages.interpolate
    msg_preamble = "伸出双指，捏住" <> @blank <> "" <> @blank <> "的嘴巴，以内力迫出毒液练药。"

    conn =
      Broadcast.publish(
        conn,
        Messages.interpolate(msg_preamble, n1: character.name, n2: target.name)
      )

    # Check snake_poison
    poison = Map.get(target.meta.temp, "snake_poison", nil)

    if is_nil(poison) or poison == %{} do
      # LPC: return notify_fail("看来你是弄不出什么毒液来了。\n" NOR);
      msg_no_poison = "看来你是弄不出什么毒液来了。"
      conn = render(conn, CommandView, "text", %{text: msg_no_poison <> "\n"})
      conn = put_character(conn, character)
      assign(conn, :prompt, false)
    else
      # Calculate lvl and amount
      lvl =
        div(Stats.skill(character.meta.stats, "poison"), 2) +
          Stats.skill(character.meta.stats, "shedu-qiqiao")

      amount = Map.get(poison, "level", 0) * Map.get(poison, "remain", 0)
      # amount capped at lvl (unused but preserved for logic)
      amount = if amount > lvl, do: lvl, else: amount

      if amount == 0 do
        # LPC: msg += WHT "$N" WHT "挤了半天，结果啥也没有挤出来，算是白忙活了。\n\n" NOR;
        msg_fail = "挤了半天，结果啥也没有挤出来，算是白忙活了。"
        conn = Broadcast.publish(conn, Messages.interpolate(msg_fail, n1: character.name))
        conn = put_character(conn, character)
        assign(conn, :prompt, false)
      else
        # Reduce remain and apply condition
        new_remain =
          div(
            Map.get(poison, "level", 1) * Map.get(poison, "remain", 0) - amount,
            Map.get(poison, "level", 1)
          )

        target = update_target_poison(target, new_remain)
        target = apply_poison_supply_condition(target)

        if amount < lvl do
          # LPC: msg += WHT "$N" WHT "挤了一点毒液出来。\n\n" NOR;
          msg_little = "挤了一点毒液出来。"
          conn = Broadcast.publish(conn, Messages.interpolate(msg_little, n1: character.name))
          # LPC: tell_object(me, HIY "可惜这点毒液连练一颗毒药都不够。\n" NOR);
          msg_not_enough = "可惜这点毒液连练一颗毒药都不够。"
          conn = render(conn, CommandView, "text", %{text: msg_not_enough <> "\n"})
          conn = put_character(conn, character)
          assign(conn, :prompt, false)
        else
          # Success: create pill
          # LPC: msg += HIM "$N" HIM "将" + target->name() + HIM "的毒液悉数挤"
          #                "出，在内力的作用下化成了一颗晶莹剔透的药丸。\n\n" NOR;
          msg_success = "将" <> @blank <> "" <> @blank <> "的毒液悉数挤出，在内力的作用下化成了一颗晶莹剔透的药丸。"

          conn =
            Broadcast.publish(
              conn,
              Messages.interpolate(msg_success, n1: character.name, n2: target.name)
            )

          # LPC: tell_object(me, HIC "你炼制了一颗蛇毒药丸。\n" NOR);
          msg_created = "你炼制了一颗蛇毒药丸。"
          conn = render(conn, CommandView, "text", %{text: msg_created <> "\n"})

          # Skill improvements (simplified)
          _exp = lvl
          # improve_skill("shedu-qiqiao", exp + random(exp))
          # improve_skill("poison", (exp + random(exp)) * 3 / 2) if poison < sk_lvl

          # Create shedu item (simplified - just record in temp)
          shedu_item = %{
            "poison" => %{
              "level" => div(lvl, 60) * 60,
              "id" => character.id,
              "name" => "蛇毒",
              "duration" => 10
            }
          }

          character = put_item_in_inventory(character, shedu_item)

          conn = put_character(conn, character)
          assign(conn, :prompt, false)
        end
      end
    end
  end

  defp update_target_poison(target, new_remain) do
    new_temp =
      Map.put(
        target.meta.temp,
        "snake_poison",
        Map.put(target.meta.temp["snake_poison"], "remain", new_remain)
      )

    %{target | meta: Map.put(target.meta, :temp, new_temp)}
  end

  defp apply_poison_supply_condition(target) do
    # Simplified: just record condition
    new_temp = Map.put(target.meta.temp, "condition/poison-supply", 1)
    %{target | meta: Map.put(target.meta, :temp, new_temp)}
  end

  defp put_item_in_inventory(character, item) do
    bag = character.meta.bag || []
    new_bag = [item | bag]
    %{character | meta: Map.put(character.meta, :bag, new_bag)}
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-50"}], "assign_refs": [{"lvl", "poison"}], "busy_lines": ["me->start_busy(random(3));"], "level_gates": [{"hamagong", "80"}, {"shedu-qiqiao", "80"}], "remote_damage": false, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // liandu.c 毒液练药
  # 
  # #include <ansi.h>
  # #include <skill.h>
  # #include <weapon.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         mapping p;
  #         string msg;
  #         object ob;
  #         int amount;
  #         int exp;
  #         int lvl;
  # //      int sk;
  #         int sk_lvl;
  # 
  #         if (! target)
  #                 return notify_fail("你要取哪条蛇的毒液练药？\n");
  # 
  #         if (! target->is_snake())
  #                 return notify_fail("看清楚些，那不是蛇，你瞎搞什么？\n");
  # 
  #         if (living(target))
  #                 return notify_fail("那条蛇还精神着呢，你找死啊。\n");
  # 
  #         if ((int)me->query_skill("shedu-qiqiao", 1) < 80)
  #                 return notify_fail("你的蛇毒奇巧还不够娴熟，不能炼制毒药。\n");
  # 
  #         //if ((int)me->query_skill("hamagong", 1) < 80)
  #                 //return notify_fail("你的蛤蟆功的修为不够，不能炼制毒药。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的内力不够！\n");
  # 
  #         me->add("neili", -50);
  #         me->start_busy(random(3));
  # 
  #         msg = HIC "\n$N" HIC "伸出双指，捏住" + target->name() +
  #               HIC "的嘴巴，以内力迫出毒液练药。\n" NOR;
  # 
  #         p = target->query("snake_poison");
  #         if (! mapp(p))
  #                 return notify_fail("看来你是弄不出什么毒液来了。\n" NOR);
  # 
  #         lvl = (int) me->query_skill("poison", 1) / 2 +
  #               (int) me->query_skill("shedu-qiqiao", 1);
  # 
  #         amount = p["level"] * p["remain"];
  #         if (amount > lvl)
  #                 amount = lvl;
  # 
  #         if (! amount)
  #         {
  #                 msg += WHT "$N" WHT "挤了半天，结果啥也没有挤出来，算是白忙活了。\n\n" NOR;
  #                 message_vision(msg, me);
  #                 return 1;
  #         }
  # 
  #         p["remain"] = (p["level"] * p["remain"] - amount) /
  #                        p["level"];
  #         target->apply_condition("poison-supply", 1);
  # 
  #         if (amount < lvl)
  #         {
  #                 msg += WHT "$N" WHT "挤了一点毒液出来。\n\n" NOR;
  #                 message_vision(msg, me);
  #                 tell_object(me, HIY "可惜这点毒液连练一颗毒药都不够。\n" NOR);
  #                 return 1;
  #         }
  # 
  #         msg += HIM "$N" HIM "将" + target->name() + HIM "的毒液悉数挤"
  #                "出，在内力的作用下化成了一颗晶莹剔透的药丸。\n\n" NOR;
  #         message_vision(msg, me);
  #         tell_object(me, HIC "你炼制了一颗蛇毒药丸。\n" NOR);
  # 
  #         sk_lvl = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
  # 
  #         // improve skill
  #         exp = lvl;
  #         //me->improve_skill("poison", exp + random(exp));
  #         if (me->can_improve_skill("shedu-qiqiao"))
  #                 me->improve_skill("shedu-qiqiao", exp + random(exp));
  # 
  #         //if (me->can_improve_skill("hamagong"))
  #         //        me->improve_skill("hamagong", 2 + random(exp / 6), 1);
  #         if (me->query_skill("poison", 1) < sk_lvl)
  #                 me->improve_skill("poison", (exp + random(exp)) * 3 / 2);
  # 
  #         // create the object
  #         ob = new("/clone/misc/shedu");
  #         ob->set("poison", ([
  #                 "level" : (lvl / 60 * 60),
  #                 "id"    : me->query("id"),
  #                 "name"  : "蛇毒",
  #                 "duration" : 10,
  #         ]));
  #         ob->move(me);
  # 
  #         return 1;
  # }
end
