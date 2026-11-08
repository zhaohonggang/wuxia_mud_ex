defmodule Kantele.Character.BeastFixtures do
  @moduledoc """
  驯兽命令测试的共享 fixture。

  `test/support` 在 `MIX_ENV=test` 下会随项目一起编译（`mix.exs`
  `elixirc_paths(:test)`），所以既能被 `mix test` 使用，也能被不启动应用、
  只加载单个 `*_test.exs` 的纯函数测试使用。

  所有外部依赖（房间广播、`kill_ob`、随机成败）都在 `build/2` 里默认注入
  到 `conn.private`，测试不需要起 Room 进程或 Ecto。
  """

  import Kalevala.ConnTest, only: [build_conn: 1]

  alias Kantele.Character.BeastState
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @room_id "test:room"

  def room_id, do: @room_id

  @doc "启动（游离的）BeastState 并清表；每个用例的 setup 调用"
  def setup_beast_state do
    BeastState.ensure!()
    BeastState.reset()
    :ok
  end

  @doc "按 LPC owner/leader/enemies 语义预置某只野兽的 NPC 侧运行态"
  def set_state(id, overrides) when is_map(overrides) do
    BeastState.update(id, fn state -> Map.merge(state || BeastState.empty(), overrides) end)
  end

  @doc "玩家角色；`training` 默认 20（>= LPC 的 10 级门）"
  def player(opts \\ []) do
    vitals = %Vitals{
      qi: 500,
      max_qi: 500,
      jing: Keyword.get(opts, :jing, 500),
      max_jing: Keyword.get(opts, :max_jing, 200),
      jingli: 200,
      max_jingli: 200,
      neili: 100,
      max_neili: 100
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: Keyword.get(opts, :int, 20),
      skills: %{"training" => Keyword.get(opts, :training, 20)},
      combat_exp: Keyword.get(opts, :combat_exp, 1_000_000),
      score: 0,
      weiwang: 0
    }

    combat = %{Combat.new() | enemies: Keyword.get(opts, :enemies, [])}

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: @room_id,
      attributes: %{},
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat,
        temp: Keyword.get(opts, :temp, %{})
      }
    }
  end

  @doc """
  房间快照里的 NPC。默认 `test:huangbiaoma` / 黄骠马，命中 `BeastTaming`
  的静态野兽登记表；`meta` 故意用普通 map，以免被 `player?/1` 认成玩家。
  """
  def beast(opts \\ []) do
    %Kalevala.Character{
      id: Keyword.get(opts, :id, "test:huangbiaoma"),
      name: Keyword.get(opts, :name, "黄骠马"),
      pid: spawn(fn -> :ok end),
      room_id: @room_id,
      attributes: Keyword.get(opts, :attributes, %{}),
      inventory: [],
      meta: %{
        vitals: %Vitals{qi: 100, max_qi: 100, jing: 100, max_jing: 100},
        stats: %Stats{combat_exp: Keyword.get(opts, :combat_exp, 1000), skills: %{}},
        combat: Combat.new()
      }
    }
  end

  @doc "另一个玩家（用于 `userp(ob)` 门）"
  def other_player(opts \\ []) do
    p = player(opts)
    %{p | id: Keyword.get(opts, :id, "player-2"), name: Keyword.get(opts, :name, "李四")}
  end

  @doc """
  构造 conn 并注入测试 seam。

  - `:characters` —— 房间 NPC 列表
  - `:roll` —— `(sp, dp) -> failed?`，默认恒成功
  - 反扑会 `send(self(), {:beast_retaliate, npc_id})`，可用 `assert_received` 断言
  - 房间广播默认吞掉，避免依赖 Room/:global
  """
  def build(p, opts \\ []) do
    conn = build_conn(p)

    private =
      conn.private
      |> Map.put(:beast_characters, Keyword.get(opts, :characters, []))
      |> Map.put(:beast_roll, Keyword.get(opts, :roll, fn _sp, _dp -> false end))
      |> Map.put(:beast_retaliate, fn npc, _me ->
        send(self(), {:beast_retaliate, Map.get(npc, :id)})
        :ok
      end)
      |> Map.put(:beast_broadcast, fn _room_id, _text -> :ok end)

    %{conn | private: private}
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

  @doc "`put_character/2` 只写 `private.update_character`，读改动必须走这里"
  def updated(conn), do: conn.private.update_character || conn.character

  @doc "取玩家 `PlayerMeta.temp[\"comedby\"]`"
  def comedby(conn) do
    temp = Map.get(updated(conn).meta, :temp) || %{}
    Map.get(temp, "comedby") || Map.get(temp, :comedby)
  end

  @doc "当前 `jing`（LPC `query(\"jing\")`）"
  def jing(conn), do: Map.get(updated(conn).meta.vitals, :jing)
end
