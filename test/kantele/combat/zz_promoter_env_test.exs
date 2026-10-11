defmodule Kantele.Combat.PromoterEnvTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills.Performs.BaguaBiao.Xian

  @root "lib/kantele/combat/skills/performs"
  @marker "由 translate_perform.py 生成"

  defp build_character(stats_overrides \\ %{}, vitals \\ Vitals.new(), combat \\ Combat.new()) do
    stats = struct(Stats.new(), stats_overrides)

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "liuxi:lianwuchang",
      meta: %PlayerMeta{vitals: vitals, stats: stats, combat: combat}
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp published_text(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn change ->
      match?({:publish, _, %Kalevala.Event{topic: Kalevala.Event.Message}, _, _}, change)
    end)
    |> Enum.map(fn {:publish, _channel, event, _opts, _error} -> event.data.text end)
    |> Enum.join("")
  end

  defp generated_modules do
    Path.wildcard("#{@root}/**/*.ex")
    |> Enum.flat_map(fn path ->
      content = File.read!(path)

      with true <- String.contains?(content, @marker),
           [_, mod] <- Regex.run(~r/^defmodule ([A-Za-z0-9_.]+) do/m, content) do
        [{path, Module.concat([mod])}]
      else
        _ -> []
      end
    end)
  end

  test "所有生成模块在游戏环境中可运行且不崩溃（默认角色）" do
    mods = generated_modules()
    assert length(mods) > 500

    failures =
      Enum.flat_map(mods, fn {path, mod} ->
        try do
          if Code.ensure_loaded?(mod) do
            conn = mod.run(build_conn(build_character()))

            if match?(%Kalevala.Character.Conn{}, conn) do
              []
            else
              [{path, :not_a_conn}]
            end
          else
            [{path, :not_loaded}]
          end
        rescue
          e -> [{path, {e.__struct__, Exception.message(e)}}]
        end
      end)

    if failures != [] do
      IO.puts("生成模块运行失败 #{length(failures)} 个：")
      Enum.each(Enum.take(failures, 20), fn {p, r} -> IO.puts("  #{p} -> #{inspect(r)}") end)
    end

    assert failures == [], "有生成模块在运行时报错"
  end

  test "perform bagua-biao.xian：门槛满足时扣内力并发布文案" do
    vitals = %{Vitals.new() | neili: 1000}

    combat = %{
      Combat.new()
      | enemies: [%{id: "npc-1", pid: self(), name: "李四", room_id: "liuxi:lianwuchang"}]
    }

    character =
      build_character(
        %{
          skills: %{"bagua-biao" => 130, "bagua-zhang" => 130, "force" => 160},
          mapped: %{"strike" => "bagua-zhang", "throwing" => "bagua-biao"},
          performs: MapSet.new(["bagua-biao/xian"])
        },
        vitals,
        combat
      )

    conn = Xian.run(build_conn(character))

    updated = conn.private.update_character
    assert updated.meta.vitals.neili == 900
    assert published_text(conn) =~ "未移植文案"
  end

  test "perform bagua-biao.xian：等级不足时拒绝" do
    character =
      build_character(%{
        skills: %{"bagua-biao" => 10, "bagua-zhang" => 10, "force" => 10},
        performs: MapSet.new(["bagua-biao/xian"])
      })

    conn = Xian.run(build_conn(character))

    assert output_text(conn) =~ "门槛不足"
  end

  test "exert hamagong.hui：无门槛时把内力清空" do
    vitals = %{Vitals.new() | neili: 1000}
    character = build_character(%{skills: %{"hamagong" => 200}}, vitals)

    conn = Kantele.Combat.Skills.Performs.Hamagong.Hui.run(build_conn(character))

    updated = conn.private.update_character
    assert updated.meta.vitals.neili == 0
  end
end
