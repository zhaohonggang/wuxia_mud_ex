defmodule Kantele.Character.NpcScriptEventTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kalevala.World.Item
  alias Kantele.Character.NpcAskEvent
  alias Kantele.Character.NpcScriptEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items

  describe "脚本化问询分发（NpcAskEvent）" do
    test "give 脚本 → npc/give 事件回玩家" do
      npc = npc(%{"铸剑" => %{"reply" => "收好这块精钢。\n", "give" => "signature:jinggang"}})

      conn = NpcAskEvent.call(build_conn(npc), ask_event("铸剑"))

      assert conn != nil

      assert_receive %Event{
        topic: "npc/give",
        data: %{npc_name: "干将", item_id: "signature:jinggang", asker_id: "player-1"}
      }
    end

    test "learn_skill 脚本 → npc/learn 事件" do
      npc = npc(%{"道法" => %{"reply" => "且听。\n", "learn_skill" => "taoism"}})

      NpcAskEvent.call(build_conn(npc), ask_event("道法"))

      assert_receive %Event{
        topic: "npc/learn",
        data: %{skill: "taoism", asker_id: "player-1"}
      }
    end

    test "family 脚本 → npc/faction 事件（带 gongxian）" do
      npc = npc(%{"拜师" => %{"reply" => "入门吧。\n", "family" => "青阳门", "gongxian" => 10}})

      NpcAskEvent.call(build_conn(npc), ask_event("拜师"))

      assert_receive %Event{
        topic: "npc/faction",
        data: %{family: "青阳门", gongxian: 10, asker_id: "player-1"}
      }
    end

    test "perform 脚本 → npc/perform 事件（带配置与 NPC 门派，供玩家侧校验）" do
      npc = %{
        npc(%{"绝户神抓" => %{"perform_id" => "huzhua-shou/juehu", "min_gongxian" => 400}})
        | meta: %Kantele.Character.NonPlayerMeta{
            inquiries: %{"绝户神抓" => %{"perform_id" => "huzhua-shou/juehu", "min_gongxian" => 400}},
            teach: %{family: "武当派", teach_skills: %{}, no_teach: []}
          }
      }

      NpcAskEvent.call(build_conn(npc), ask_event("绝户神抓"))

      assert_receive %Event{
        topic: "npc/perform",
        data: %{perform_id: "huzhua-shou/juehu", npc_family: "武当派", asker_id: "player-1"}
      }
    end

    test "纯文本问询保持原有行为（不进脚本分支）" do
      npc = npc(%{"莫邪" => "她是吾妻。\n"})

      NpcAskEvent.call(build_conn(npc), ask_event("莫邪"))

      refute_receive %Event{topic: "npc/give"}, 100
      refute_receive %Event{topic: "npc/learn"}, 100
      refute_receive %Event{topic: "npc/faction"}, 100
    end
  end

  describe "玩家侧领物（NpcScriptEvent.npc/give）" do
    setup do
      Items.put("signature:jinggang", %Item{
        id: "signature:jinggang",
        name: "精钢块 Steel Ingot",
        verbs: [],
        callback_module: Kantele.World.Item,
        meta: %Meta{weight: 100, value: 500}
      })

      :ok
    end

    test "给物入背包并渲染回话" do
      conn = NpcScriptEvent.give_result(build_conn(player()), give_event())

      updated = conn.private.update_character || conn.character

      assert [%Item.Instance{item_id: "signature:jinggang"}] = updated.inventory
      assert output_text(conn) =~ "递到你手中"
    end

    test "它人领物事件不处理" do
      event = %{give_event() | data: %{give_event().data | asker_id: "someone"}}
      conn = NpcScriptEvent.give_result(build_conn(player()), event)

      assert conn.private.update_character == nil
    end
  end

  describe "玩家侧传技（NpcScriptEvent.npc/learn）" do
    test "学会新技能（stats.skills 首学 1 级）" do
      conn = NpcScriptEvent.learn_result(build_conn(player()), learn_event())

      updated = conn.private.update_character || conn.character

      assert updated.meta.stats.skills["taoism"] == 1
      assert output_text(conn) =~ "领悟了「taoism」"
    end
  end

  describe "玩家侧拜师（NpcScriptEvent.npc/faction）" do
    test "写入 family 并发放门派贡献" do
      conn = NpcScriptEvent.faction_result(build_conn(player()), faction_event())

      updated = conn.private.update_character || conn.character

      assert updated.meta.family.name == "青阳门"
      assert updated.meta.stats.gongxian == 10
      assert output_text(conn) =~ "青阳门"
    end
  end

  describe "玩家侧授绝招（NpcScriptEvent.npc/perform）" do
    test "全门槛达标：学会绝招并扣门派贡献" do
      p =
        player(
          stats: %{
            skills: %{"huzhua-shou" => 120, "force" => 180},
            gongxian: 500,
            shen: 100_000,
            performs: MapSet.new()
          }
        )

      conn = NpcScriptEvent.perform_result(build_conn(p), perform_event())
      updated = conn.private.update_character || conn.character

      assert MapSet.member?(updated.meta.stats.performs, "huzhua-shou/juehu")
      assert updated.meta.stats.gongxian == 100
      assert output_text(conn) =~ "学会了「huzhua-shou/juehu」"
    end

    test "门槛不过（贡献不足）：不落盘并提示" do
      p =
        player(
          stats: %{
            skills: %{"huzhua-shou" => 120, "force" => 180},
            gongxian: 10,
            shen: 100_000
          }
        )

      conn = NpcScriptEvent.perform_result(build_conn(p), perform_event())

      assert conn.private.update_character == nil
      assert output_text(conn) =~ "效力还不够"
    end

    test "非同门：拒绝授招（读玩家 meta.family）" do
      p =
        player(
          stats: %{
            skills: %{"huzhua-shou" => 120, "force" => 180},
            gongxian: 500,
            shen: 100_000
          },
          family: %{name: "青阳门"}
        )

      conn = NpcScriptEvent.perform_result(build_conn(p), perform_event())

      assert conn.private.update_character == nil
      assert output_text(conn) =~ "并非同门"
    end

    test "它人事件不处理" do
      event = %{perform_event() | data: %{perform_event().data | asker_id: "someone"}}
      conn = NpcScriptEvent.perform_result(build_conn(player()), event)

      assert conn.private.update_character == nil
    end
  end

  # ---- helpers ----

  defp npc(inquiries) do
    %Kalevala.Character{
      id: "signature:ganjiang",
      name: "干将",
      pid: self(),
      room_id: "test:room",
      meta: %Kantele.Character.NonPlayerMeta{inquiries: inquiries}
    }
  end

  defp ask_event(keyword),
    do: %Event{
      topic: "characters/ask",
      data: %{reply_to: self(), asker_id: "player-1", asker_name: "张三", keyword: keyword}
    }

  defp give_event(),
    do: %Event{
      topic: "npc/give",
      data: %{npc_name: "干将", item_id: "signature:jinggang", asker_id: "player-1"}
    }

  defp learn_event(),
    do: %Event{
      topic: "npc/learn",
      data: %{npc_name: "青阳子", skill: "taoism", asker_id: "player-1"}
    }

  defp faction_event(),
    do: %Event{
      topic: "npc/faction",
      data: %{npc_name: "青阳子", family: "青阳门", gongxian: 10, asker_id: "player-1"}
    }

  defp perform_event() do
    %Event{
      topic: "npc/perform",
      data: %{
        npc_name: "俞莲舟",
        npc_family: "武当派",
        asker_id: "player-1",
        config: %{
          "perform_id" => "huzhua-shou/juehu",
          "skill" => "huzhua-shou",
          "min_levels" => %{"force" => 180, "huzhua-shou" => 120},
          "min_gongxian" => 400,
          "min_shen" => 100_000,
          "cost_gongxian" => 400
        }
      }
    }
  end

  defp player(opts \\ []) do
    stats = struct(Stats.new(), Keyword.get(opts, :stats, %{}))

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: stats,
        combat: Kantele.Character.Combat.new(),
        family: Keyword.get(opts, :family)
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
end