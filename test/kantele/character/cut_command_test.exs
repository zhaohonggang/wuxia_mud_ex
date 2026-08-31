defmodule Kantele.Character.CutCommandTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kalevala.World.Item
  alias Kantele.Character.CutCommand
  alias Kantele.Character.CutEvent
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.NpcCutEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Items
  alias Kantele.World.Room.CutRequestEvent

  setup do
    for {item_id, name} <- [{"test:meat", "兽肉"}, {"test:leather", "兽皮"}] do
      Items.put(item_id, %Item{
        id: item_id,
        name: name,
        verbs: [],
        callback_module: Kantele.World.Item,
        meta: %Kantele.World.Item.Meta{}
      })
    end

    :ok
  end

  defp player(id \\ "player-1", name \\ "张三", inventory \\ []) do
    %Kalevala.Character{
      id: id,
      name: name,
      pid: self(),
      room_id: "test:room",
      inventory: inventory,
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp corpse(overrides \\ %{}) do
    parts = %{
      "head" => [3, "颗", "头", "头", "head", nil, "割了下来", "test:meat"],
      "hide" => [2, "张", "兽皮", "兽皮", "hide", nil, nil, "test:leather"],
      "horn" => [4, "根", "犄角", "犄角", "horn", nil, nil, nil]
    }

    base = %Kalevala.Character{
      id: "npc:heihu",
      name: "黑虎",
      pid: self(),
      room_id: "test:room",
      status: "黑虎的尸体躺在地上。",
      meta: %NonPlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new(),
        parts: parts,
        no_cut: %{},
        default_clone: nil,
        been_cut: nil,
        defeated_by: nil
      }
    }

    Map.merge(base, overrides)
  end

  defp cut_data(overrides \\ %{}) do
    Map.merge(
      %{
        part: "head",
        name: "黑虎",
        id: "npc:heihu",
        requester_id: "player-1",
        requester_name: "张三",
        weapon_skill_type: nil,
        weapon_name: nil,
        skills: %{"force" => 100},
        force: 100,
        reply_to: self()
      },
      overrides
    )
  end

  defp conn_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp room_text(%{output: output}) do
    output
    |> Enum.map(fn {_pid, %{data: data}} -> IO.iodata_to_binary(data) end)
    |> Enum.join("")
  end

  describe "路由解析" do
    test "cut 部位 from 尸体" do
      {:ok, parsed} = Kantele.Character.Commands.parse("cut 头 from 黑虎")
      assert parsed.function == :run
      assert parsed.params["arg"] == "头 from 黑虎"
    end

    test "cut 尸体（无 from 纯参）" do
      {:ok, parsed} = Kantele.Character.Commands.parse("cut 黑虎")
      assert parsed.function == :run
      assert parsed.params["arg"] == "黑虎"
    end

    test "裸 cut 走 run_bare" do
      {:ok, parsed} = Kantele.Character.Commands.parse("cut")
      assert parsed.function == :run_bare
    end
  end

  describe "CutCommand 发布 room/cut" do
    test "空参数提示" do
      conn = CutCommand.run(build_conn(player()), %{"arg" => ""})
      assert conn_text(conn) =~ "你要割什么东西？"
    end

    test "裸 cut 经 run_bare 提示" do
      conn = CutCommand.run_bare(build_conn(player()), %{})
      assert conn_text(conn) =~ "你要割什么东西？"
    end

    test "cut 部位 from 尸体 发布 room/cut" do
      conn = CutCommand.run(build_conn(player()), %{"arg" => "头 from 黑虎"})

      assert [%Event{topic: "room/cut", data: data}] = conn.events
      assert data.part == "头"
      assert data.name == "黑虎"
    end

    test "cut 尸体 发布 part=? 的 room/cut" do
      conn = CutCommand.run(build_conn(player()), %{"arg" => "黑虎"})

      assert [%Event{topic: "room/cut", data: data}] = conn.events
      assert data.part == "?"
      assert data.name == "黑虎"
    end

    test "携带武器快照与修为" do
      equipped = %{weapon: %{name: "长剑", skill_type: "sword", damage: 10}}

      char = %{
        player()
        | meta: %{player().meta | combat: %{player().meta.combat | equipped: equipped}}
      }

      conn = CutCommand.run(build_conn(char), %{"arg" => "头 from 黑虎"})

      assert [%Event{topic: "room/cut", data: data}] = conn.events
      assert data.weapon_skill_type == "sword"
      assert data.weapon_name == "长剑"
      # Stats.new() 默认 force 20，Stats.effective 无映射加成
      assert data.force == 20
    end
  end

  describe "房间 CutRequestEvent 守卫与转发" do
    defp room_context(requester, target) do
      %Kalevala.World.Room.Context{
        characters: Enum.reject([requester, target], &is_nil/1),
        item_instances: []
      }
    end

    defp other_pid, do: spawn(fn -> :ok end)

    test "找到尸体则转 characters/cut 给尸体进程" do
      requester = player()
      target = %{corpse() | pid: other_pid()}
      ctx = room_context(requester, target)

      result =
        CutRequestEvent.call(ctx, %Event{
          from_pid: requester.pid,
          topic: "room/cut",
          data: %{name: "黑虎", part: "?"}
        })

      assert [{to_pid, %Event{topic: "characters/cut"} = event}] = result.events
      assert to_pid == target.pid
      assert event.data.part == "?"
      assert event.data.reply_to == requester.pid
      assert event.data.requester_name == "张三"
      assert event.data.name == "黑虎"
    end

    test "活人不让割" do
      requester = player()
      target = %{corpse() | pid: other_pid(), status: "黑虎 is here."}
      ctx = room_context(requester, target)

      result =
        CutRequestEvent.call(ctx, %Event{
          from_pid: requester.pid,
          topic: "room/cut",
          data: %{name: "黑虎", part: "?"}
        })

      assert room_text(result) =~ "活人你也敢割，找打么。"
      assert result.events == []
    end

    test "割自己拒绝" do
      requester = player("player-1", "张三")
      ctx = room_context(requester, nil)

      result =
        CutRequestEvent.call(ctx, %Event{
          from_pid: requester.pid,
          topic: "room/cut",
          data: %{name: "张三", part: "?"}
        })

      assert room_text(result) =~ "割自己？你有毛病啊？"
    end

    test "附近没有该目标" do
      requester = player()
      ctx = room_context(requester, nil)

      result =
        CutRequestEvent.call(ctx, %Event{
          from_pid: requester.pid,
          topic: "room/cut",
          data: %{name: "老虎", part: "?"}
        })

      assert room_text(result) =~ "你附近没有这样东西。"
      assert result.events == []
    end
  end

  describe "尸体侧 NpcCutEvent do_cut" do
    defp call_npc(corpse_char, data) do
      NpcCutEvent.call(build_conn(corpse_char), %Event{topic: "characters/cut", data: data})
    end

    test "无 parts 配置统一拒绝" do
      conn = call_npc(%{corpse() | meta: %{corpse().meta | parts: nil}}, cut_data())

      assert_receive %Event{topic: "cut/result", data: %{kind: :text, text: text}}
      assert text =~ "看来你是割不下来什么东西了。"
    end

    test "? 列出可割部位" do
      _conn = call_npc(corpse(), cut_data(%{part: "?"}))

      assert_receive %Event{topic: "cut/result", data: %{kind: :text, text: text}}
      assert text =~ "黑虎有以下部位可以割下来。"
      assert text =~ "头"
      assert text =~ "(head)"
      assert text =~ "犄角"
      assert text =~ "(horn)"
    end

    test "? 全部割完提示无处下刀" do
      meta = %{corpse().meta | been_cut: ["head", "hide", "horn"]}
      _conn = call_npc(%{corpse() | meta: meta}, cut_data(%{part: "?"}))

      assert_receive %Event{topic: "cut/result", data: %{kind: :text, text: text}}
      assert text =~ "黑虎已经没什么可以下刀的地方了。"
    end

    test "空手内力不足拒绝" do
      data = cut_data(%{force: 20, skills: %{"force" => 20}})
      _conn = call_npc(corpse(), data)

      assert_receive %Event{topic: "cut/result", data: %{kind: :text, text: text}}
      assert text =~ "好好练练内功再来吧。"
    end

    test "针法修为不足拒绝" do
      data = cut_data(%{weapon_skill_type: "pin", weapon_name: "银针", skills: %{"sword" => 50}})
      _conn = call_npc(corpse(), data)

      assert_receive %Event{topic: "cut/result", data: %{kind: :text, text: text}}
      assert text =~ "尚且无法用针进行切割"
    end

    test "针法达标可割" do
      data = cut_data(%{weapon_skill_type: "pin", weapon_name: "银针", skills: %{"sword" => 120}})

      _conn = call_npc(corpse(), data)

      assert_receive %Event{topic: "cut/result", data: %{kind: :grant, scene: scene} = payload}
      assert scene =~ "张三轻弹出手中银针"
      assert payload.item_id == "test:meat"
      assert payload.unit == "颗"
      assert payload.part_name == "头"
    end

    test "割下部位入包并记录 been_cut" do
      conn = call_npc(corpse(), cut_data())

      assert_receive %Event{topic: "cut/result", data: %{kind: :grant, scene: scene}}
      assert scene =~ "张三举起手来"
      assert scene =~ "黑虎的头"

      updated = conn.private.update_character || conn.character
      assert "head" in updated.meta.been_cut
    end

    test "反复割同部位拒绝" do
      meta = %{corpse().meta | been_cut: ["head"]}
      _conn = call_npc(%{corpse() | meta: meta}, cut_data())

      assert_receive %Event{topic: "cut/result", data: %{kind: :text, text: text}}
      assert text =~ "头已经被割走了。"
    end

    test "no_cut 部位拒绝" do
      meta = %{corpse().meta | no_cut: %{"horn" => "这样东西你割不下来。"}}
      _conn = call_npc(%{corpse() | meta: meta}, cut_data(%{part: "horn"}))

      assert_receive %Event{topic: "cut/result", data: %{kind: :text, text: text}}
      assert text =~ "这样东西你割不下来。"
    end

    test "未知部位提示" do
      _conn = call_npc(corpse(), cut_data(%{part: "nose"}))

      assert_receive %Event{topic: "cut/result", data: %{kind: :text, text: text}}
      assert text =~ "找不到你想割的部位"
    end

    test "部位无 clone 时用 default_clone" do
      meta = %{corpse().meta | default_clone: "test:meat"}
      _conn = call_npc(%{corpse() | meta: meta}, cut_data(%{part: "horn"}))

      assert_receive %Event{topic: "cut/result", data: %{kind: :grant, item_id: "test:meat"}}
    end

    test "割头清除 defeated_by（cut.c head 分支）" do
      meta = %{corpse().meta | defeated_by: "player-1"}
      conn = call_npc(%{corpse() | meta: meta}, cut_data())

      updated = (conn.private.update_character || conn.character).meta
      assert updated.defeated_by == nil

      assert_receive %Event{topic: "cut/result", data: %{kind: :grant}}
    end
  end

  describe "玩家侧 CutEvent.result" do
    test "grant 产物实例入包并渲染" do
      conn =
        CutEvent.result(build_conn(player()), %Event{
          topic: "cut/result",
          data: %{
            kind: :grant,
            scene: "张三提起手中剑「嗤」的一声便将黑虎的头割了下来。",
            item_id: "test:meat",
            unit: "颗",
            part_name: "头"
          }
        })

      updated = conn.private.update_character || conn.character
      assert [%Item.Instance{item_id: "test:meat"}] = updated.inventory
      assert conn_text(conn) =~ "便将黑虎的头割了下来。"
      assert conn_text(conn) =~ "你拣起一颗头。"
    end

    test "text 直接展示" do
      conn =
        CutEvent.result(build_conn(player()), %Event{
          topic: "cut/result",
          data: %{kind: :text, text: "你附近没有这样东西。\n"}
        })

      assert conn_text(conn) =~ "你附近没有这样东西。"
    end
  end
end
