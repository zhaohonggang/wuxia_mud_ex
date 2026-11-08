defmodule Kantele.Character.InteractionFixtures do
  @moduledoc """
  `special` / `stab` / `touch` 三个命令测试的共享 fixture。

  `test/support` 在 `MIX_ENV=test` 下随项目一起编译，故纯函数 harness
  （`Code.require_file` + `ExUnit.run()`）也能用。所有外部依赖
  （`Kantele.World.Items` 缓存、房间进程、`Presence`）都通过 `conn.private`
  注入，测试不需要启动应用监督树。
  """

  import Kalevala.ConnTest, only: [build_conn: 1]

  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @room_id "test:room"

  def room_id, do: @room_id

  @doc """
  玩家角色。默认已出生（`meta.env.born`）且带两项普通特技。
  `opts` 可覆盖 `:attributes` / `:env` / `:specials` / `:inventory` / `:wiz_level` /
  `:busy` / `:name`。
  """
  def player(opts \\ []) do
    specials = Keyword.get(opts, :specials, %{"piyi" => true, "strength" => true})

    attributes =
      Keyword.get(
        opts,
        :attributes,
        %{"special_skills" => specials, "wiz_level" => Keyword.get(opts, :wiz_level, 0)}
      )

    env = Keyword.get(opts, :env, %{born: "扬州人氏", registered: true})
    combat = if Keyword.get(opts, :busy, false), do: Combat.start_busy(Combat.new(), 2), else: Combat.new()

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: @room_id,
      attributes: attributes,
      inventory: Keyword.get(opts, :inventory, []),
      meta: %PlayerMeta{
        vitals: %Vitals{qi: 500, max_qi: 500, jing: 500, max_jing: 500},
        stats: %Stats{str: 20, dex: 20, con: 20, int: 20},
        combat: combat,
        env: env
      }
    }
  end

  @doc "物品定义；`actions` 可注入 `%{verb: ..., handler: ...}` 动作表"
  def item(opts \\ []) do
    %Kalevala.World.Item{
      id: Keyword.get(opts, :id, "item:changjian"),
      name: Keyword.get(opts, :name, "长剑"),
      description: "一把普通的剑。",
      meta: %{
        aliases: Keyword.get(opts, :aliases, ["changjian"]),
        actions: Keyword.get(opts, :actions, [])
      }
    }
  end

  @doc "物品实例；`item` 字段直接嵌定义，避免依赖 Items 缓存"
  def instance(opts \\ []) do
    item = Keyword.get(opts, :item, item())

    %Kalevala.World.Item.Instance{
      id: Keyword.get(opts, :id, "inst-1"),
      item_id: item.id,
      item: item,
      meta: %{}
    }
  end

  @doc "房间里的 NPC（用于 `touch` 的 is_character 门）"
  def npc(opts \\ []) do
    %Kalevala.Character{
      id: Keyword.get(opts, :id, "npc:shibei"),
      name: Keyword.get(opts, :name, "石碑"),
      pid: self(),
      room_id: @room_id,
      attributes: %{},
      inventory: [],
      meta: %{}
    }
  end

  @doc """
  构造 conn 并注入测试 seam。

  - `:items` —— `item_id => item 定义`（默认空，因实例自带 `item` 字段通常不需要）
  - `:room` —— 房间快照（`private.characters` / `private.item_instances`）
  - `:handlers` —— handler 名 => `{module, function}`
  - `:players` —— 在线玩家列表（巫师 `special <id>` 用）
  """
  def build(p, opts \\ []) do
    conn = build_conn(p)

    private =
      conn.private
      |> Map.put(:item_use_items, Keyword.get(opts, :items, %{}))
      |> Map.put(:item_use_handlers, Keyword.get(opts, :handlers, %{}))
      |> Map.put(:item_use_room, room(opts))
      |> Map.put(:special_players, Keyword.get(opts, :players, []))

    %{conn | private: private}
  end

  defp room(opts) do
    %{
      id: @room_id,
      private: %{
        characters: Keyword.get(opts, :characters, []),
        item_instances: Keyword.get(opts, :room_items, [])
      }
    }
  end

  @doc "拼接命令写入 conn 的文本"
  def output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end
end
