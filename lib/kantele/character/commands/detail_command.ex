defmodule Kantele.Character.DetailCommand do
  @moduledoc """
  综合状态命令：`detail [玩家]`

  无参数显示自己的 score + info + 背包（i）合并输出；
  带 `<玩家>` 时仅巫师可查看（在线取实时状态，离线展示存档快照）。
  """

  use Kalevala.Character.Command

  import Kalevala.Character.Conn

  alias Kalevala.Character
  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.Character.DetailView
  alias Kantele.Character.Presence
  alias Kantele.Character.Records
  alias Kantele.Character.ScoreView
  alias Kantele.Character.Stats
  alias Kantele.World.Items

  def run_bare(conn, _params), do: run(conn, %{"rest" => ""})

  def run(conn, params) do
    case String.trim(params["rest"] || "") do
      "" ->
        render_character(conn, conn.character, true)

      name ->
        case Access.wizardp(conn.character) do
          false ->
            fail(conn, "你没有巫师的权限。\n")

          true ->
            if String.downcase(name) == String.downcase(conn.character.name) do
              render_character(conn, conn.character, true)
            else
              case lookup_character(name) do
                {:ok, character} -> render_character(conn, character, false)
                :error -> fail(conn, "找不到玩家 #{name}。\n")
              end
            end
        end
    end
  end

  # ---- 目标查找（在线优先，离线读存档） ----

  defp lookup_character(name) do
    case find_online(name) do
      character when not is_nil(character) ->
        {:ok, character}

      nil ->
        case Records.load(name) do
          {:ok, metadata, wiz_level} ->
            {:ok, build_character(name) |> Records.apply_to_character({:ok, metadata}, wiz_level)}

          :error ->
            :error
        end
    end
  end

  defp find_online(name) do
    key = name |> String.downcase() |> String.trim()

    case Enum.find(Presence.characters(), fn character ->
           to_string(character.name) |> String.downcase() == key
         end) do
      nil ->
        nil

      character ->
        live_character(character)
    end
  end

  defp live_character(character) do
    try do
      case :sys.get_state(character.pid) do
        %Kalevala.Character.Foreman{character: %Character{} = live} -> live
        _ -> character
      end
    catch
      _, _ -> character
    end
  end

  defp build_character(name) do
    %Character{
      id: Character.generate_id(),
      pid: self(),
      room_id: Kantele.World.start_room_id(),
      name: name,
      status: "#{name} is here.",
      description: "#{name} is a person.",
      inventory: [],
      meta: %Kantele.Character.PlayerMeta{
        vitals: Kantele.Character.Vitals.new(),
        stats: Kantele.Character.Stats.new(),
        combat: Kantele.Character.Combat.new(),
        coins: 0
      }
    }
  end

  # ---- 渲染数据 ----

  defp render_character(conn, character, self?) do
    conn
    |> assign(:name, character.name)
    |> assign(:self?, self?)
    |> assign(:score, score_assigns(character))
    |> assign(:info, info_assigns(character))
    |> assign(:items, item_instances(character))
    |> render(DetailView, "display")
  end

  defp score_assigns(character) do
    stats = character_stats(character)

    %{
      name: character.name,
      vitals: character_vitals(character),
      str: stats.str,
      dex: stats.dex,
      con: stats.con,
      int: stats.int,
      combat_exp: stats.combat_exp,
      potential: stats.potential,
      coins: Map.get(character.meta, :coins) || 0,
      score: stats.score || 0,
      weiwang: stats.weiwang || 0,
      gongxian: stats.gongxian || 0,
      skills: expanded_skills(stats),
      performs:
        stats.performs
        |> MapSet.to_list()
        |> Enum.map(&ScoreView.perform_title/1)
        |> Enum.sort()
    }
  end

  defp expanded_skills(stats) do
    stats.skills
    |> Enum.sort_by(fn {name, _level} -> name end)
    |> Enum.map(fn {name, level} ->
      %{
        name: ScoreView.skill_title(name),
        level: level,
        mapped: ScoreView.mapped_title(stats, name)
      }
    end)
  end

  defp info_assigns(character) do
    stats = character_stats(character)

    %{
      vitals: character_vitals(character),
      str: stats.str,
      dex: stats.dex,
      con: stats.con,
      int: stats.int,
      combat_exp: stats.combat_exp,
      potential: stats.potential,
      force_level: level_with_special(stats, "force"),
      sword_level: level_with_special(stats, "sword"),
      dodge_level: Stats.skill(stats, "dodge"),
      parry_level: Stats.skill(stats, "parry"),
      unarmed_level: Stats.skill(stats, "unarmed")
    }
  end

  defp level_with_special(stats, base) do
    base_lvl = Stats.skill(stats, base)

    case Map.get(stats.mapped, base) do
      nil ->
        "#{base_lvl} 级"

      special_id ->
        "#{base_lvl} 级（#{special_title(special_id)} #{Stats.skill(stats, special_id)} 级）"
    end
  end

  defp special_title(id), do: special_titles()[id] || id

  defp special_titles() do
    %{
      "liuxin-jian" => "柳心剑法",
      "liuxi-neigong" => "柳溪内功"
    }
  end

  defp character_stats(character) do
    Map.get(character.meta, :stats, Stats.new())
  end

  defp character_vitals(character) do
    Map.get(character.meta, :vitals, Kantele.Character.Vitals.new())
  end

defp item_instances(character) do
  character
  |> Map.get(:inventory, [])
  |> normalize_inventory()
  |> Enum.flat_map(fn item_instance ->
    case item_instance.item do
      %Kalevala.World.Item.ItemNotLoaded{} ->
        case safe_item(item_instance) do
          nil -> []
          item -> [%{item_instance | item: item}]
        end

      item ->
        [%{item_instance | item: item}]
    end
  end)
end

defp normalize_inventory(items) when is_list(items), do: items

defp normalize_inventory(_other), do: []

  defp safe_item(instance) do
    Items.get!(instance.item_id)
  rescue
    _ -> nil
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end