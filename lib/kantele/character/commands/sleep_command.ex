defmodule Kantele.Character.SleepCommand do
  @moduledoc """
  睡眠命令：`sleep` / `睡觉`

  对应 LPC cmds/std/sleep.c。
  在可睡眠场所（sleep_room 或有 sleepbag）睡眠恢复精气内。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.World.Items

  def run(conn, _params) do
    character = conn.character
    room = conn.private.room || %{}  # 从 conn 获取房间信息

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

      conditions_prevent_sleep?(character) ->
        conn
        |> render(CommandView, "text", %{text: "你想合上眼睛好好睡上一觉，可是身体不适，辗转反侧就是睡不着。\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        start_sleep(conn, character, room)
    end
  end

  defp can_sleep_here?(character, room) do
    is_gaibang = (character.attributes["family"] || %{})["family_name"] == "丐帮"
    has_sleepbag = Enum.any?(character.inventory, fn inst ->
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

  defp conditions_prevent_sleep?(character) do
    conditions = Map.get(character.meta, :conditions, %{})

    Enum.any?(conditions, fn {_cnd_name, cnd_info} ->
      # 简化：如果有任意 condition 且 qi/jing 低于阈值
      min_qi = cnd_info["min_qi"] || 0
      min_jing = cnd_info["min_jing"] || 0
      qi = Map.get(character.attributes, "qi", 0)
      jing = Map.get(character.attributes, "jing", 0)

      qi < min_qi || jing < min_jing
    end)
  end

  defp start_sleep(conn, character, room) do
    room_attrs = Map.get(room, :attrs, %{})
    is_hotel = room_attrs["hotel"] == true
    has_sleepbag = Enum.any?(character.inventory, fn inst ->
      Kalevala.Meta.get(Items.get!(inst.item_id).meta, "sleepbag") == true
    end)
    room_sleep = room_attrs["sleep_room"] == true

    # 设置睡眠状态
    new_temp = character.meta.temp
      |> Map.put("block_msg/all", 1)
      |> Map.put("sleeped", 1)
      |> Map.put("no_get", 1)
      |> Map.put("no_get_from", 1)

    if is_hotel do
      new_temp = Map.delete(new_temp, "rent_paid")
    end

    # 增加睡眠计数
    sleep_count = (character.meta.state["sleep"] || 0) + 1
    new_state = Map.put(character.meta.state, "sleep", sleep_count)

    new_meta = character.meta
      |> Map.put(:temp, new_temp)
      |> Map.put(:state, new_state)

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
    delay_ms = 10000 + :rand.uniform(5000)  # 10-15秒
    delay_event(conn, delay_ms, "sleep/wakeup", %{character_id: character_id})
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end