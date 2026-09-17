defmodule Kantele.Character.DetachCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kantele.Character.DetachCommand
  alias Kantele.Character.DetachEvent
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.NpcFamilyEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp npc(opts \\ []) do
    %Kalevala.Character{
      id: Keyword.get(opts, :id, "wudang:yu"),
      name: Keyword.get(opts, :name, "俞莲舟"),
      pid: self(),
      room_id: "test:room",
      meta: %NonPlayerMeta{
        teach: %{family: "武当派", teach_skills: %{}, no_teach: []}
      }
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

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      jingli: Keyword.get(opts, :jingli, 2000),
      neili: Keyword.get(opts, :neili, 9000),
      max_neili: Keyword.get(opts, :max_neili, 10000),
      max_jingli: Keyword.get(opts, :max_jingli, 2000),
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: Keyword.get(opts, :max_qi, 5000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20),
      skills: Keyword.get(opts, :skills, %{}),
      combat_exp: Keyword.get(opts, :combat_exp, 0),
      score: Keyword.get(opts, :score, 0),
      weiwang: Keyword.get(opts, :weiwang, 0),
      gongxian: Keyword.get(opts, :gongxian, 0)
    }

    combat = Kantele.Character.Combat.new()

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat,
        family: Keyword.get(opts, :family, nil)
      }
    }
  end

  describe "detach 命令" do
    test "发送family/detach事件" do
      p = player()
      conn = DetachCommand.run(build_conn(p), %{"name" => "师父"})
      events = Enum.filter(conn.events, fn e -> e.topic == "family/detach" end)
      assert length(events) == 1
      event = hd(events)
      assert event.data.name == "师父"
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("detach 师父")
      assert parsed.module == DetachCommand
    end
  end

  describe "NPC 侧叛师回执（family/detach-result）" do
    test "有 teach.family 的 NPC 回门派身份（不再读 NonPlayerMeta 不存在的 :family）" do
      NpcFamilyEvent.detach(build_conn(npc()), %Event{
        topic: "family/detach",
        data: %{reply_to: self(), student_id: "player-1", student_name: "张三"}
      })

      assert_receive %Event{topic: "family/detach-result", data: data}
      assert data.ok == true
      assert data.family == "武当派"
      assert data.master_id == "wudang:yu"
      assert data.master_name == "俞莲舟"
    end

    test "无 teach 的 NPC 婉拒" do
      plain = %{npc() | meta: %NonPlayerMeta{}}

      NpcFamilyEvent.detach(build_conn(plain), %Event{
        topic: "family/detach",
        data: %{reply_to: self(), student_id: "player-1", student_name: "张三"}
      })

      assert_receive %Event{topic: "family/detach-result", data: data}
      assert data.ok == false
    end
  end

  describe "玩家侧叛师判定（DetachEvent.detach_result）" do
    test "嫡传弟子叛师：降武功一重 + 清贡献 + 清门派并落盘" do
      p =
        player(
          family: %{name: "武当派", master_id: "wudang:yu", master_name: "俞莲舟"},
          skills: %{"sword" => 10, "force" => 50},
          gongxian: 120
        )

      conn =
        DetachEvent.detach_result(build_conn(p), %Event{
          topic: "family/detach-result",
          data: %{ok: true, family: "武当派", master_id: "wudang:yu", master_name: "俞莲舟"}
        })

      updated = conn.private.update_character || conn.character

      assert updated.meta.family == nil
      assert updated.meta.stats.skills == %{"sword" => 9, "force" => 49}
      assert updated.meta.stats.gongxian == 0
      assert output_text(conn) =~ "叛离"
    end

    test "非门下弟子请求叛师：noop，不落盘" do
      p = player(family: %{name: "峨眉派", master_id: "emei:x", master_name: "灭绝"})

      conn =
        DetachEvent.detach_result(build_conn(p), %Event{
          topic: "family/detach-result",
          data: %{ok: true, family: "武当派", master_id: "wudang:yu", master_name: "俞莲舟"}
        })

      assert conn.private.update_character == nil
      assert output_text(conn) =~ "并非我门下"
    end

    test "无门派的玩家请求叛师：noop（不崩 on nil family）" do
      conn =
        DetachEvent.detach_result(build_conn(player()), %Event{
          topic: "family/detach-result",
          data: %{ok: true, family: "武当派", master_id: "wudang:yu", master_name: "俞莲舟"}
        })

      assert conn.private.update_character == nil
      assert output_text(conn) =~ "并非我门下"
    end

    test "NPC 婉拒回执：展示原因，不落盘" do
      conn =
        DetachEvent.detach_result(build_conn(player()), %Event{
          topic: "family/detach-result",
          data: %{ok: false, reason: "老朽并无门派，何来叛师之说？"}
        })

      assert conn.private.update_character == nil
      assert output_text(conn) =~ "并无门派"
    end
  end
end
