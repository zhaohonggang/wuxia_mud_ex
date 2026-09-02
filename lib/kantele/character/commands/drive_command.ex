defmodule Kantele.Character.DriveCommand do
  @moduledoc """
  驾车命令：`drive <车辆> <方向>`

  对应 LPC cmds/std/drive.c。
  赶车向指定方向移动，需要 driving 技能和可驾驶的载具。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Item.Transport

  @direction_map %{
    "n" => "north", "s" => "south", "e" => "east", "w" => "west",
    "nu" => "northup", "su" => "southup", "eu" => "eastup", "wu" => "westup",
    "nd" => "northdown", "sd" => "southdown", "ed" => "eastdown", "wd" => "westdown",
    "ne" => "northeast", "nw" => "northwest", "se" => "southeast", "sw" => "southwest"
  }

  @direction_chinese %{
    "north" => "北", "south" => "南", "east" => "东", "west" => "西",
    "northup" => "北边", "southup" => "南边", "eastup" => "东边", "westup" => "西边",
    "northdown" => "北边", "southdown" => "南边", "eastdown" => "东边", "westdown" => "西边",
    "northeast" => "东北", "northwest" => "西北", "southeast" => "东南", "southwest" => "西南"
  }

  def run(conn, %{"vehicle" => vehicle, "direction" => direction}) do
    character = conn.character

    if vehicle == "" or direction == "" do
      conn
      |> render(CommandView, "text", %{text: "你要赶什么往哪个方向？\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      do_drive(conn, character, vehicle, direction)
    end
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "你要赶什么？\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp do_drive(conn, character, vehicle_name, direction_input) do
    # 解析方向
    direction = normalize_direction(direction_input)

    if !direction do
      conn
      |> render(CommandView, "text", %{text: "你不能往这个方向赶车。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      # 查找载具
      case find_vehicle(character, vehicle_name) do
        {:ok, vehicle_item, vehicle_instance} ->
          # 检查是否可驾驶
          if Transport.can_drive_by?(vehicle_item, character) do
            # 检查战斗/忙碌
            if character.meta.combat.enemies != [] do
              conn
              |> render(CommandView, "text", %{text: "你现在正在和人家动手，没空赶车。\n"})
              |> prompt(CommandView, "prompt", %{})
            else
              # 驾驶技能检定
              driving_skill = character.skills["driving"] || 0

              if :rand.uniform(driving_skill + 100) < 50 do
                conn
                |> render(CommandView, "text", %{text: "#{character.name}手忙脚乱的折腾了半天，可是#{vehicle_item.name}一动不动。\n"})
                |> prompt(CommandView, "prompt", %{})
                # busy 1 秒（简化）
              else
                # 尝试移动
                case attempt_move(conn, character, vehicle_item, direction) do
                  {:ok, new_conn} ->
                    # 可能 busy
                    if :rand.uniform(driving_skill + 100) < 30 do
                      # 简化：不实现 busy，仅技能提升
                      nil
                    end

                    # 技能提升
                    if driving_skill > 0 && :rand.uniform(100) < 10 do
                      # 简化：不实际提升技能
                      nil
                    end

                    new_conn
                  {:error, reason} ->
                    conn
                    |> render(CommandView, "text", %{text: reason <> "\n"})
                    |> prompt(CommandView, "prompt", %{})
                end
              end
            end

          else
            conn
            |> render(CommandView, "text", %{text: "你看清楚了，这不是能驱使的车辆！\n"})
            |> prompt(CommandView, "prompt", %{})
          end

        {:error, reason} ->
          conn
          |> render(CommandView, "text", %{text: reason <> "\n"})
          |> prompt(CommandView, "prompt", %{})
      end
    end
  end

  defp find_vehicle(character, name) do
    Enum.find(character.inventory, fn inst ->
      item = Items.get!(inst.item_id)
      item.callback_module.matches?(item, name)
    end)
    |> case do
      nil -> {:error, "这里没有这样东西让你赶啊！"}
      instance ->
        item = Items.get!(instance.item_id)
        {:ok, item, instance}
    end
  end

  defp normalize_direction(input) do
    cond do
      @direction_map[input] -> @direction_map[input]
      Map.has_key?(@direction_chinese, input) -> input
      true -> nil
    end
  end

  defp attempt_move(conn, character, vehicle_item, direction) do
    # 简化：直接尝试移动
    # 实际应调用 GO_CMD 类似逻辑
    room = get_room(conn)
    exits = Map.get(room, :attrs, %{})["exits"] || %{}

    if Map.has_key?(exits, direction) do
      target_room_id = exits[direction]
      # 移动玩家和载具
      new_conn = move_character(conn, character, target_room_id, direction)

      # 显示离开/到达消息
      new_conn = show_move_messages(new_conn, character, vehicle_item, direction)

      {:ok, new_conn}
    else
      {:error, "那个方向没有路。\n"}
    end
  end

  defp get_room(conn) do
    conn.private.room || %{}
  end

  defp move_character(conn, character, target_room_id, direction) do
    # 简化：直接更新角色位置
    new_character = %{character | room_id: target_room_id}
    put_character(conn, new_character)
  end

defp show_move_messages(conn, character, vehicle_item, direction) do
    cdir = @direction_chinese[direction] || direction
    reverse_dir = get_reverse_direction(direction)
    rdir = @direction_chinese[reverse_dir] || reverse_dir

    msgs = [
      {:msg_leave, "$N一声吆喝，赶着$n向" <> cdir <> "驶去。",
       :msg_arrival, "只听一声吆喝，$N赶着$n从" <> rdir <> "驶来。"},
      {:msg_leave, "$N一言不发，只是赶着$n向" <> cdir <> "驶去。",
       :msg_arrival, "只见$N闷头闷脑的赶着$n从" <> rdir <> "驶了过来。"},
      {:msg_leave, "$N喝道：\"让开了！让开了\"，只见人和$n已经滚滚朝着" <> cdir <> "去了。",
       :msg_arrival, "远远的只听一阵喝声，紧接着就见$N赶着$n滚滚的从" <> rdir <> "驶了过来。"},
      {:msg_leave, "$N抹了抹汗，继续赶着$n往" <> cdir <> "去了。",
       :msg_arrival, "只见$N一边抹汗，一边赶着$n从" <> rdir <> "驶了过来。"},
      {:msg_leave, "只听隆隆声响，就见$N急冲冲的赶着$n奔" <> cdir <> "去了。",
       :msg_arrival, "只听隆隆声响，就见$N急冲冲的赶着$n从" <> rdir <> "驶来。"}
    ]

    {_, msg_leave, _, msg_arrival} = Enum.random(msgs)

    # 显示给玩家
    room = get_room(conn)
    leave_msg = interpolate(msg_leave, [character, vehicle_item])

    conn
    |> render(CommandView, "text", %{text: leave_msg <> "\n"})
    |> render(CommandView, "text", %{text: "你赶着#{vehicle_item.name}到了#{Map.get(room, :attrs, %{})["short"] || "某处"}。\n"})
  end

  defp interpolate(template, [character, vehicle]) do
    template
    |> String.replace("$N", character.name)
    |> String.replace("$n", vehicle.name)
  end

  defp get_reverse_direction(dir) do
    case dir do
      "north" -> "south"
      "south" -> "north"
      "east" -> "west"
      "west" -> "east"
      "northup" -> "southdown"
      "southup" -> "northdown"
      "eastup" -> "westdown"
      "westup" -> "eastdown"
      "northdown" -> "southup"
      "southdown" -> "northup"
      "eastdown" -> "westup"
      "westdown" -> "eastup"
      "northeast" -> "southwest"
      "northwest" -> "southeast"
      "southeast" -> "northwest"
      "southwest" -> "northeast"
      _ -> dir
    end
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end