defmodule Kantele.Character.SleepEvent do
  @moduledoc """
  睡眠醒来事件处理：sleep/wakeup 延迟触发，执行醒来逻辑
  """

  use Kalevala.Character.Event

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records

  def wakeup(conn, %{data: %{character_id: character_id}}) do
    character = conn.character

    if character.id != character_id do
      conn
    else
      wakeup_character(conn, character)
    end
  end

  defp wakeup_character(conn, character) do
    # 检查是否还在睡眠中
    if character.meta.temp["sleeped"] != true do
      conn
    else
      # 清除睡眠状态
      new_temp = character.meta.temp
        |> Map.delete("block_msg/all")
        |> Map.delete("sleeped")
        |> Map.delete("no_get")
        |> Map.delete("no_get_from")

      # 检查冷却时间
      last_sleep = character.attributes["last_sleep"] || 0
      now = :os.system_time(:second)
      is_gaibang = (character.attributes["family"] || %{})["family_name"] == "丐帮"
      cooldown = if is_gaibang, do: 30, else: 60

      if now - last_sleep >= cooldown do
        # 完全恢复
        new_vitals = character.meta.vitals
          |> Map.put(:qi, Map.get(character.meta.vitals, :max_qi, 100))
          |> Map.put(:jing, Map.get(character.meta.vitals, :max_jing, 100))

        # 内力恢复
        max_neili = Map.get(character.meta.vitals, :max_neili, 0)
        current_neili = Map.get(character.meta.vitals, :neili, 0)
        neili_gain = div(max_neili * 4, 5) - div(current_neili * 4, 5)
        new_neili = min(current_neili + neili_gain, max_neili)
        new_vitals = Map.put(new_vitals, :neili, new_neili)

        # 更新 last_sleep
        new_attrs = Map.put(character.attributes, "last_sleep", :os.system_time(:second))

        new_meta = character.meta
          |> Map.put(:vitals, new_vitals)
          |> Map.put(:attributes, new_attrs)
          |> Map.put(:temp, Map.delete(character.meta.temp, "sleeped") |> Map.delete("block_msg/all") |> Map.delete("no_get") |> Map.delete("no_get_from"))

        new_character = %{character | meta: new_meta, attributes: new_attrs}
        new_conn = put_character(conn, new_character)

        new_conn
        |> render(CommandView, "text", %{text: "你一觉醒来，只觉精力充沛。该活动一下了。\n"})
        |> prompt(CommandView, "prompt", %{})
        |> save()
      else
        # 冷却未满，仅醒来不恢复
        new_temp = Map.delete(character.meta.temp, "sleeped") |> Map.delete("block_msg/all") |> Map.delete("no_get") |> Map.delete("no_get_from")
        new_meta = Map.put(character.meta, :temp, new_temp)
        new_character = %{character | meta: new_meta}
        new_conn = put_character(conn, new_character)

        new_conn
        |> render(CommandView, "text", %{text: "你迷迷糊糊的睁开双眼，爬了起来。\n"})
        |> prompt(CommandView, "prompt", %{})
        |> save()
      end
    end
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end