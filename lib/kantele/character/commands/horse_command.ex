defmodule Kantele.Character.HorseCommand do
  @moduledoc """
  马夫购买坐骑：`horse` / `买马` / `buy_mount <马夫>`

  交互流程（对应 HorseBoss 模块）：
  1. `horse <马夫>` — 显示问候与物种列表
  2. `horse <马夫> <物种>` — 选择物种（马/驴/骡/骆驼/...）
  3. `horse <马夫> gender <公|母>` — 选择性别
  4. `horse <马夫> id <英文ID>` — 设置召唤 ID
  5. `horse <马夫> name <中文名>` — 设置名字
  6. `horse <马夫> desc <描述>` — 设置描述（可选），完成购买
  7. `horse <马夫> cancel` — 取消购买，清理临时状态

  临时状态存储在 `meta.temp`：
  - `horse_npc` - 目标 NPC id
  - `chosen_species` - 已选物种
  - `pet_gender` - 性别
  - `pet_id` - 召唤 ID
  - `pet_name` - 名字
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.NPC.Horseboss
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records

@species_map %{
    "horse" => "horse", "马" => "horse",
    "donkey" => "donkey", "驴" => "donkey",
    "mule" => "mule", "骡" => "mule",
    "camel" => "camel", "骆驼" => "camel",
    "ox" => "ox", "牛" => "ox",
    "elephant" => "elephant", "大象" => "elephant",
    "lion" => "lion", "狮子" => "lion",
    "tiger" => "tiger", "老虎" => "tiger",
    "leopard" => "leopard", "豹子" => "豹子",
    "deer" => "deer", "鹿" => "鹿",
    "crane" => "crane", "仙鹤" => "仙鹤",
    "eagle" => "eagle", "老鹰" => "老鹰",
    "goat" => "goat", "山羊" => "山羊",
    "monkey" => "monkey", "猴子" => "猴子",
    "bear" => "bear", "黑熊" => "黑熊",
    "wolf" => "wolf", "狼" => "狼",
    "fox" => "fox", "狐狸" => "狐狸",
    "marten" => "marten", "貂" => "貂",
    "foal" => "foal", "小马驹" => "foal",
    "beast" => "beast", "异兽" => "beast"
  }

  @species_list [
    "horse", "马",
    "donkey", "驴",
    "mule", "骡",
    "camel", "骆驼",
    "ox", "牛",
    "elephant", "大象",
    "lion", "狮子",
    "tiger", "老虎",
    "leopard", "豹子",
    "deer", "鹿",
    "crane", "仙鹤",
    "eagle", "老鹰",
    "goat", "山羊",
    "monkey", "猴子",
    "bear", "黑熊",
    "wolf", "狼",
    "fox", "狐狸",
    "marten", "貂",
    "foal", "小马驹",
    "beast", "异兽"
  ]

  def run(conn, %{"name" => name, "rest" => rest}) do
    rest = String.trim(rest || "")
    args = String.split(rest)

    cond do
      args == [] ->
        show_greeting(conn, name)

      args == ["cancel"] ->
        cancel_purchase(conn, name)

      true ->
        case args do
          [species_key] when species_key in @species_list ->
            choose_species(conn, name, @species_map[species_key])

          ["gender", gender] ->
            choose_gender(conn, name, gender)

          ["id", id] ->
            choose_id(conn, name, id)

          ["name", name_part | rest_name] ->
            choose_name(conn, name, [name_part | rest_name] |> Enum.join(" "))

          ["desc" | rest_desc] ->
            choose_desc(conn, name, Enum.join(rest_desc, " "))

          ["desc"] ->
            choose_desc(conn, name, "")

          _ ->
            usage(conn)
        end
    end
  end

  def run(conn, %{"name" => name}) do
    show_greeting(conn, name)
  end

  defp show_greeting(conn, npc_name) do
    target = find_npc(conn, npc_name)

    case target do
      nil ->
        reply(conn, "这里没有这个人。\n")

      target ->
        # 验证是否为马夫
        if Horseboss.is_horseboss?(target) do
          greeting = Horseboss.greet(target, conn.character)

          # 记录当前交互的 NPC
          new_meta = PlayerMeta.put_temp(conn.character.meta, "horse_npc", target.id)
          new_character = %{conn.character | meta: new_meta}

          conn
          |> put_character(new_character)
          |> reply(greeting <> "\n")
        else
          reply(conn, "#{target.name}不是马夫。\n")
        end
    end
  end

  defp choose_species(conn, npc_name, species_key) do
    target = find_npc(conn, npc_name)
    horse_npc = PlayerMeta.get_temp(conn.character.meta, "horse_npc")

    cond do
      is_nil(target) or target.id != horse_npc ->
        reply(conn, "请先对马夫使用 horse 命令。\n")

      true ->
        {:ok, msg} = Horseboss.start_purchase(target, conn.character, species_key)

        new_meta = PlayerMeta.put_temp(conn.character.meta, "chosen_species", species_key)
        new_character = %{conn.character | meta: new_meta}
        Records.save(new_character)

        reply(conn, msg <> "\n")
    end
  end

  defp choose_gender(conn, npc_name, gender) do
    target = find_npc(conn, npc_name)
    horse_npc = PlayerMeta.get_temp(conn.character.meta, "horse_npc")
    chosen_species = PlayerMeta.get_temp(conn.character.meta, "chosen_species")

    cond do
      is_nil(target) or target.id != horse_npc ->
        reply(conn, "请先对马夫使用 horse 命令。\n")

      is_nil(chosen_species) ->
        reply(conn, "请先选择物种。\n")

      true ->
        case Horseboss.choose_gender(target, conn.character, gender) do
          {:error, msg} ->
            reply(conn, msg <> "\n")

          msg ->
            new_meta = PlayerMeta.put_temp(conn.character.meta, "pet_gender",
              if gender in ["male", "公"] do
                "male"
              else
                "female"
              end)
            new_character = %{conn.character | meta: new_meta}
            Records.save(new_character)
            reply(conn, msg <> "\n")
        end
    end
  end

  defp choose_id(conn, npc_name, id) do
    target = find_npc(conn, npc_name)
    horse_npc = PlayerMeta.get_temp(conn.character.meta, "horse_npc")

    cond do
      is_nil(target) or target.id != horse_npc ->
        reply(conn, "请先对马夫使用 horse 命令。\n")

      is_nil(PlayerMeta.get_temp(conn.character.meta, "pet_gender")) ->
        reply(conn, "请先选择性别。\n")

      true ->
        case Horseboss.choose_id(target, conn.character, id) do
          {:error, msg} ->
            reply(conn, msg <> "\n")

          msg ->
            new_meta = PlayerMeta.put_temp(conn.character.meta, "pet_id", id)
            new_character = %{conn.character | meta: new_meta}
            Records.save(new_character)
            reply(conn, msg <> "\n")
        end
    end
  end

  defp choose_name(conn, npc_name, name) do
    target = find_npc(conn, npc_name)
    horse_npc = PlayerMeta.get_temp(conn.character.meta, "horse_npc")

    cond do
      is_nil(target) or target.id != horse_npc ->
        reply(conn, "请先对马夫使用 horse 命令。\n")

      is_nil(PlayerMeta.get_temp(conn.character.meta, "pet_id")) ->
        reply(conn, "请先设置 ID。\n")

      true ->
        case Horseboss.choose_name(target, conn.character, name) do
          {:error, msg} ->
            reply(conn, msg <> "\n")

          msg ->
            new_meta = PlayerMeta.put_temp(conn.character.meta, "pet_name", name)
            new_character = %{conn.character | meta: new_meta}
            Records.save(new_character)
            reply(conn, msg <> "\n")
        end
    end
  end

  defp choose_desc(conn, npc_name, desc) do
    target = find_npc(conn, npc_name)
    horse_npc = PlayerMeta.get_temp(conn.character.meta, "horse_npc")

    cond do
      is_nil(target) or target.id != horse_npc ->
        reply(conn, "请先对马夫使用 horse 命令。\n")

      is_nil(PlayerMeta.get_temp(conn.character.meta, "pet_name")) ->
        reply(conn, "请先设置名字。\n")

      true ->
        {:ok, msg} = Horseboss.choose_desc(target, conn.character, desc)

        # 清理临时状态
        new_meta = conn.character.meta
        |> PlayerMeta.delete_temp("horse_npc")
        |> PlayerMeta.delete_temp("chosen_species")
        |> PlayerMeta.delete_temp("pet_gender")
        |> PlayerMeta.delete_temp("pet_id")
        |> PlayerMeta.delete_temp("pet_name")

        new_character = %{conn.character | meta: new_meta}
        Records.save(new_character)

        reply(conn, msg <> "\n")
    end
  end

  defp cancel_purchase(conn, npc_name) do
    target = find_npc(conn, npc_name)
    horse_npc = PlayerMeta.get_temp(conn.character.meta, "horse_npc")

    cond do
      is_nil(target) or target.id != horse_npc ->
        reply(conn, "没有进行中的购买。\n")

      true ->
        msg = Horseboss.cancel(target, conn.character)

        new_meta = conn.character.meta
        |> PlayerMeta.delete_temp("horse_npc")
        |> PlayerMeta.delete_temp("chosen_species")
        |> PlayerMeta.delete_temp("pet_gender")
        |> PlayerMeta.delete_temp("pet_id")
        |> PlayerMeta.delete_temp("pet_name")

        new_character = %{conn.character | meta: new_meta}
        Records.save(new_character)

        reply(conn, msg <> "\n")
    end
  end

  defp find_npc(conn, name) do
    Enum.find(conn.character.room_characters || [], fn c ->
      c.id != conn.character.id && (c.id == name || String.downcase(c.name) == String.downcase(name))
    end)
  end

  defp usage(conn) do
    reply(conn, """
用法：
  horse <马夫>                    # 查看问候与物种列表
  horse <马夫> <物种>            # 选择物种（马/驴/骡/骆驼/大象/狮子/老虎/豹子/鹿/仙鹤/老鹰/山羊/猴子/黑熊/狼/狐狸/貂/小马驹/异兽）
  horse <马夫> gender <公|母>    # 选择性别
  horse <马夫> id <英文ID>       # 设置召唤 ID（3-20 小写字母/下划线）
  horse <马夫> name <中文名>     # 设置名字（2-12 中文字）
  horse <马夫> desc [描述]       # 设置描述并完成购买
  horse <马夫> cancel            # 取消购买
""")
  end

  defp reply(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end