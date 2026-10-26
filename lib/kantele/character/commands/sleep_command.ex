defmodule Kantele.Character.SleepCommand do
  @moduledoc """
  睡眠命令：`sleep` / `睡觉`

  对应 LPC cmds/std/sleep.c。
  在可睡眠场所（sleep_room 或有 sleepbag）睡眠恢复精气内。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.ConditionRegistry
  alias Kantele.Character.Conditions
  alias Kantele.Character.Records
  alias Kantele.World.Items

  def run(conn, _params) do
    character = conn.character
    # 从实时快照/注入获取房间信息
    room = get_room(conn)
    # LPC: cnd = me->query_condition(); 有拦路条件则睡不着
    blocking = sleep_blocking_condition(conn)

    cond do
      not can_sleep_here?(character, room) ->
        conn
        |> render(CommandView, "text", %{text: "这里不是你能睡的地方！\n"})
        |> prompt(CommandView, "prompt", %{})

      character.meta.combat.enemies != [] ->
        conn
        |> render(CommandView, "text", %{text: "战斗中不能睡觉！\n"})
        |> prompt(CommandView, "prompt", %{})

      character.meta.temp["busy"] ->
        conn
        |> render(CommandView, "text", %{text: "你正忙着呢！\n"})
        |> prompt(CommandView, "prompt", %{})

      hotel_needs_payment?(character, room) ->
        conn
        |> render(CommandView, "text", %{text: "店小二从门外对你大叫：把这里当避难所啊？先到一楼付钱后再来睡！\n"})
        |> prompt(CommandView, "prompt", %{})

      vitals_too_low?(character) ->
        conn
        |> render(CommandView, "text", %{text: "你现在接近昏迷，睡不着觉。\n"})
        |> prompt(CommandView, "prompt", %{})

      is_binary(blocking) ->
        refuse_by_condition(conn, blocking)

      true ->
        start_sleep(conn, character, room)
    end
  end

  defp get_room(conn) do
    Map.get(conn, :room) ||
      Map.get(conn.private, :room) ||
      Kantele.World.Room.snapshot(conn.character.room_id)
  end

  defp can_sleep_here?(character, room) do
    is_gaibang = (character.attributes["family"] || %{})["family_name"] == "丐帮"

    has_sleepbag =
      Enum.any?(character.inventory, fn inst ->
        Kalevala.Meta.get(Items.get!(inst.item_id).meta, "sleepbag") == true
      end)

    room_sleep = Map.get(room, :attrs, %{})["sleep_room"] == true
    room_no_sleep = Map.get(room, :attrs, %{})["no_sleep_room"] == true

    cond do
      room_no_sleep -> false
      is_gaibang -> room_sleep || has_sleepbag
      true -> room_sleep || has_sleepbag
    end
  end

  defp hotel_needs_payment?(character, room) do
    Map.get(room, :attrs, %{})["hotel"] == true && character.meta.temp["rent_paid"] != true
  end

  defp vitals_too_low?(character) do
    qi = Map.get(character.attributes, "qi", 0)
    jing = Map.get(character.attributes, "jing", 0)
    qi < 0 || jing < 0
  end

  # LPC `cmds/std/sleep.c`：
  #
  #   cnd = me->query_condition();
  #   if (cnd && sizeof(cnd))
  #       for (i = 0; i < sizeof(kc); i++)
  #           if (CONDITION_D(kc[i])->min_qi_needed(me) > qi ||
  #               CONDITION_D(kc[i])->min_jing_needed(me) > jing)
  #                   message("vision", me->name() + "看样子是想睡觉，可是辗转反侧，"
  #                           "就是睡不着。\n", environment(me), me);
  #                   tell_object(me, "你想合上眼睛好好睡上一觉，可是" +
  #                               to_chinese(kc[i]) + "不断折磨着你，让你辗转难眠。\n");
  #                   return 1;
  #
  defp sleep_blocking_condition(conn) do
    Conditions.blocked_by_vitals(
      get_session(conn, "conditions") || %{},
      conn.character.attributes || %{},
      &ConditionRegistry.daemon/1
    )
  end

  # LPC 同时发两条：房间 vision（不含自己）+ 本人带条件名的 tell。
  defp refuse_by_condition(conn, cnd) do
    name = ConditionRegistry.chinese_name(cnd)

    conn
    |> publish_message(
      "rooms:#{conn.character.room_id}",
      "{npc}看样子是想睡觉，可是辗转反侧，就是睡不着。\n",
      [type: "vision"],
      &publish_error/2
    )
    |> render(CommandView, "text", %{
      text: "你想合上眼睛好好睡上一觉，可是#{name}不断折磨着你，让你辗转难眠。\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end

  defp publish_error(conn, _error), do: conn

  defp start_sleep(conn, character, room) do
    room_attrs = Map.get(room, :attrs, %{})
    is_hotel = room_attrs["hotel"] == true

    has_sleepbag =
      Enum.any?(character.inventory, fn inst ->
        Kalevala.Meta.get(Items.get!(inst.item_id).meta, "sleepbag") == true
      end)

    room_sleep = room_attrs["sleep_room"] == true

    # 设置睡眠状态
    new_temp =
      character.meta.temp
      |> Map.put("block_msg/all", 1)
      |> Map.put("sleeped", true)
      |> Map.put("no_get", 1)
      |> Map.put("no_get_from", 1)

    if is_hotel do
      new_temp = Map.delete(new_temp, "rent_paid")
    end

    # 增加睡眠计数（PlayerMeta 无 state 字段，计数放入 temp）
    sleep_count = (character.meta.temp["sleep_count"] || 0) + 1
    new_temp = Map.put(new_temp, "sleep_count", sleep_count)

    new_meta = Map.put(character.meta, :temp, new_temp)

    new_character = %{character | meta: new_meta}
    new_conn = put_character(conn, new_character)

    # 显示睡眠消息
    msg =
      cond do
        room_attrs["sleep_room"] == true ->
          "你往床上一躺，开始睡觉。\n不一会儿，你就进入了梦乡。\n"

        has_sleepbag ->
          "你展开一个睡袋，钻了进去，开始睡觉。\n不一会儿，你就进入了梦乡。\n"

        true ->
          "你往地下角落一躺，开始睡觉。\n不一会儿，你就进入了梦乡。\n"
      end

    new_conn
    |> render(CommandView, "text", %{text: msg})
    |> assign(:prompt, false)
    |> delay_wakeup(character.id)
    |> save()
  end

  defp delay_wakeup(conn, character_id) do
    # 10-15秒
    delay_ms = 10000 + :rand.uniform(5000)
    delay_event(conn, delay_ms, "sleep/wakeup", %{character_id: character_id})
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end
