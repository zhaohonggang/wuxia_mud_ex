defmodule Kantele.Character.SkillCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.SkillCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(stats_opts \\ []) do
    stats =
      Stats.new()
      |> struct(
        Keyword.merge(
          [
            skills: %{"sword" => 30, "dodge" => 20},
            mapped: %{"sword" => "boshi-sword"},
            performs: MapSet.new(["sword/qimen", "dodge/zongyan"]),
            combat_exp: 0,
            score: 0,
            potential: 100,
            weiwang: 0
          ],
          stats_opts
        )
      )

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: stats,
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp run(character, params), do: SkillCommand.run(build_conn(character), params)

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  test "显示技能等级与有效等级" do
    text = run(player(), %{"skill_name" => "sword"}) |> output_text()

    assert text =~ "关于「sword」的详细属性"
    assert text =~ "技能等级：  30"
    assert text =~ "有效等级：  30"
  end

  test "映射特技参与有效等级计算" do
    p =
      player(
        skills: %{"force" => 10, "liuxi-neigong" => 20},
        mapped: %{"force" => "liuxi-neigong"}
      )

    text = run(p, %{"skill_name" => "force"}) |> output_text()

    assert text =~ "有效等级：  30"
    assert text =~ "映射特技：  liuxi-neigong（20级）"
  end

  test "列出已学绝招" do
    text = run(player(), %{"skill_name" => "sword"}) |> output_text()
    assert text =~ "已学绝招：  sword/qimen"
  end

  test "无参数提示用法" do
    text = run(player(), %{}) |> output_text()
    assert text =~ "指令格式：skill <技能名>"
  end

  test "路由解析" do
    {:ok, parsed} = Kantele.Character.Commands.parse("skill sword")
    assert parsed.module == SkillCommand
  end
end