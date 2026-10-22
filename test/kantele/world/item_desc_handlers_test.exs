defmodule Kantele.World.ItemDescHandlersTest.FakeRoom do
  use GenServer

  def start_link(room_id) do
    GenServer.start_link(__MODULE__, room_id, name: {:global, {Kalevala.World.Room, room_id}})
  end

  @impl true
  def init(room_id) do
    {:ok,
     %{
       data: %Kantele.World.Room{id: room_id},
       private: %{characters: [], item_instances: []}
     }}
  end
end

defmodule Kantele.World.ItemDescHandlersTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.World.ItemDescHandlersTest.FakeRoom
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.ItemDescHandlers
  alias Kantele.World.ItemDescHandlers.GatedText
  alias Kantele.World.ItemDescHandlers.PlayerTempBranch
  alias Kantele.World.ItemDescHandlers.RoomOccupancyText
  alias Kantele.World.ItemDescHandlers.RoomTempText
  alias Kantele.World.ItemDescHandlers.RoomTempTiers
  alias Kantele.World.ItemDescHandlers.ScoreTiers
  alias Kantele.World.ItemDescHandlers.PlayerSkill
  alias Kantele.World.ItemDescHandlers.ArenaState
  alias Kantele.World.ItemDescHandlers.FingerDKiller
  alias Kantele.World.ItemDescHandlers.GaoshiVisitor
  alias Kantele.World.ItemDescHandlers.PigTable
  alias Kantele.World.Arena
  alias Kantele.World.FingerD
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Hengyang.Furong1.Pull
  alias Kantele.World.RoomActions.Hengyang.Inzhushendong.Gua
  alias Kantele.World.RoomActions.Hengyang.Zigaihole.Move

  @config %{
    "kind" => "gated_text",
    "gate_temp" => "gua",
    "hidden" => "尘土已将其掩盖。",
    "shown" => "只见山壁上刻有三副巨图。"
  }

  @jing_config %{
    "kind" => "score_tiers",
    "tiers" => [
      %{"min_score" => 0, "text" => "你看了半天，只看到自己的影子，没发现什么。"},
      %{"min_score" => 1000, "text" => "你觉得上面镌的经偈似乎有些不同。"},
      %{"min_score" => 5000, "text" => "你发现上面镌的经偈光泽和别处不一样，难道可以掀(xian)开？"}
    ]
  }

  @hua_config %{
    "kind" => "score_tiers",
    "tiers" => [
      %{"min_score" => 0, "text" => "这是一幅陈旧的画卷，没有什么不同。"},
      %{
        "min_score" => 3000,
        "text" => "这是一幅陈旧的画卷，画中一处微微隆起，你忍不住便想掀开看看。",
        "set_temp" => "marks/画1"
      }
    ]
  }

  @liang_config %{
    "kind" => "player_temp_branch",
    "gate_temp" => "marks/辟1",
    "no_access" => "你要看什么？",
    "room_key" => "move",
    "hidden" => "一根楠木做的房梁，可惜年代太久，已经腐烂得不成样子了。",
    "shown" => "一根楠木做的房梁，上面有崭新的刮痕，似乎不久前才有人动过。",
    "set_temp" => "marks/辟2"
  }

  @bi_config %{
    "kind" => "player_skill",
    "skill" => "literate",
    "min_level" => 1,
    "has_text" => "识字者看到的蝌蚪文。",
    "no_text" => "文盲看到的壁画。"
  }

  @pet_config %{
    "kind" => "player_skill",
    "family" => "星宿派",
    "skill" => "xingxiu-qishu",
    "min_level" => 160,
    "has_text" => "上面刻有金蜈蚣，黑寡妇，赤蝎子，千年灵蛇，花斑毒蟾。你心中一惊：“难道这便是五圣剧毒？”",
    "no_text" => "上面刻有蜈蚣，蜘蛛，蝎子，蛇，蟾蜍五种毒物。"
  }

  @tiaofu_config %{
    "kind" => "arena_state",
    "open_text" => "本擂台现在自由开放。",
    "closed_text" => "本擂台现在被 {name} 暂时关闭。"
  }

  @gaoshi_config %{
    "kind" => "finger_d_killer",
    "footer" => "\n成都提督\n吴天德\n"
  }

  @gaoshi_visitor_config %{
    "kind" => "gaoshi_visitor"
  }

  @pig_table_config %{
    "kind" => "pig_table"
  }

  @bi_tiers_config %{
    "kind" => "room_temp_tiers",
    "tiers" => [
      %{"key" => "marks/破", "text" => "石壁已经被打破了。"},
      %{"key" => "marks/推", "text" => "石门已经被推开了，却露出一个山洞来。"}
    ],
    "default" => "这块石壁看起来很坚实。"
  }

  test "item_desc_entry/2 distinguishes static and dynamic entries" do
    room = %Room{id: "z:r", item_desc: %{"wall" => "墙上写着字。", "bi" => @config}}

    assert Room.item_desc_entry(room, "wall") == {:static, "墙上写着字。"}
    assert Room.item_desc_entry(room, "bi") == {:dynamic, @config}
    assert Room.item_desc_entry(room, "nope") == nil
  end

  test "lookup/2 resolves the pilot handler and degrades safely" do
    assert ItemDescHandlers.lookup("hengyang:inzhushendong", "gated_text") ==
             {:ok, {GatedText, :run}}

    assert ItemDescHandlers.lookup("hengyang:inzhushendong", "missing") ==
             {:unimplemented, "missing"}
  end

  test "lookup/2 resolves the score-gated rooms" do
    assert ItemDescHandlers.lookup("shaolin:putiyuan", "score_tiers") ==
             {:ok, {ScoreTiers, :run}}

    assert ItemDescHandlers.lookup("beijing:aofu_shufang", "score_tiers") ==
             {:ok, {ScoreTiers, :run}}
  end

  test "ScoreTiers selects the highest tier at or below the score" do
    context = %Kalevala.World.Room.Context{data: %Room{}}

    assert run_score(context, 0, @jing_config) ==
             "你看了半天，只看到自己的影子，没发现什么。\n"

    assert run_score(context, 1000, @jing_config) ==
             "你觉得上面镌的经偈似乎有些不同。\n"

    assert run_score(context, 4999, @jing_config) ==
             "你觉得上面镌的经偈似乎有些不同。\n"

    assert run_score(context, 5000, @jing_config) ==
             "你发现上面镌的经偈光泽和别处不一样，难道可以掀(xian)开？\n"
  end

  test "ScoreTiers sends set_temp only on the tier that declares it" do
    context = %Kalevala.World.Room.Context{data: %Room{}}

    low = ScoreTiers.run(context, requester_with_score(2999), %{config: @hua_config})
    assert low.events == []

    high = ScoreTiers.run(context, requester_with_score(3000), %{config: @hua_config})

    assert [
             {pid, %{topic: "character/effects", data: %{effects: [{:set_temp, "marks/画1", 1}]}}}
           ] = high.events

    assert pid == self()
  end

  test "ScoreTiers falls back safely without tiers" do
    context = %Kalevala.World.Room.Context{data: %Room{}}
    assert run_score(context, 9999, %{}) == "这里没有这个东西。\n"
  end

  test "GatedText hides the text until the temp flag is set" do
    context = %Kalevala.World.Room.Context{data: %Room{}}

    hidden = GatedText.run(context, requester(%{}), %{config: @config})
    assert context_output(hidden) == "尘土已将其掩盖。\n"

    shown = GatedText.run(context, requester(%{"gua" => 1}), %{config: @config})
    assert context_output(shown) == "只见山壁上刻有三副巨图。\n"
  end

  test "Gua sets the gua temp flag on success" do
    conn = %Conn{character: %{meta: %PlayerMeta{combat: nil}}}

    conn = Gua.run(conn, %{trailing: "bi", room_id: "hengyang:inzhushendong"})

    assert conn_output(conn) ==
             "\n你走到山壁旁，将山壁上的尘土一一刮去，后面景象一一显露了出来。\n"

    assert conn.private.update_character.meta.temp["gua"] == 1
  end

  test "Gua rejects an unknown target without setting the flag" do
    conn = %Conn{character: %{meta: %PlayerMeta{combat: nil}}}

    conn = Gua.run(conn, %{trailing: "wall", room_id: "hengyang:inzhushendong"})

    assert conn_output(conn) == "你要刮什么？\n"
    assert conn.private.update_character == nil
  end

  test "lookup/2 resolves the room-state handlers" do
    assert ItemDescHandlers.lookup("hengyang:furong1", "room_temp") ==
             {:ok, {RoomTempText, :run}}

    assert ItemDescHandlers.lookup("hengyang:zigaihole", "room_temp") ==
             {:ok, {RoomTempText, :run}}

    assert ItemDescHandlers.lookup("guanwai:jingxiu", "room_occupancy") ==
             {:ok, {RoomOccupancyText, :run}}

    assert ItemDescHandlers.lookup("fuzhou:mishi", "score_tiers") ==
             {:ok, {ScoreTiers, :run}}

    assert ItemDescHandlers.lookup("fuzhou:mishi", "player_temp_branch") ==
             {:ok, {PlayerTempBranch, :run}}
  end

  test "RoomTempText switches on room temp state" do
    target_room = "test:room_temp"
    looker_room = "test:looker_temp"
    start_supervised!({FakeRoom, target_room})
    context = %Kalevala.World.Room.Context{data: %Room{id: looker_room}}

    config = %{
      "kind" => "room_temp",
      "room_id" => target_room,
      "key" => "marks/拉",
      "hidden" => "蜘蛛网完好。",
      "shown" => "蜘蛛网已被拉破。"
    }

    hidden = RoomTempText.run(context, requester(%{}), %{config: config, room_id: looker_room})
    assert context_output(hidden) == "蜘蛛网完好。\n"

    assert :ok = Room.put_state_by_id(target_room, "marks/拉", 1)

    shown = RoomTempText.run(context, requester(%{}), %{config: config, room_id: looker_room})
    assert context_output(shown) == "蜘蛛网已被拉破。\n"
  end

  test "RoomTempText reads the current room from context without a process call" do
    room_id = "test:current_room"

    context = %Kalevala.World.Room.Context{
      data: %Room{id: room_id, state: %{"marks/拉" => 1}}
    }

    config = %{
      "kind" => "room_temp",
      "key" => "marks/拉",
      "hidden" => "蜘蛛网完好。",
      "shown" => "蜘蛛网已被拉破。"
    }

    shown = RoomTempText.run(context, requester(%{}), %{config: config, room_id: room_id})
    assert context_output(shown) == "蜘蛛网已被拉破。\n"
  end

  test "RoomOccupancyText reads the target room snapshot" do
    target_room = "test:occupancy"
    looker_room = "test:jingxiu"
    pid = start_supervised!({FakeRoom, target_room})
    context = %Kalevala.World.Room.Context{data: %Room{id: looker_room}}

    config = %{
      "kind" => "room_occupancy",
      "room_id" => target_room,
      "hidden" => "门上挂了个牌子：休息室",
      "shown" => "门上挂了个牌子：休息中、请毋打扰"
    }

    empty =
      RoomOccupancyText.run(context, requester(%{}), %{config: config, room_id: looker_room})

    assert context_output(empty) == "门上挂了个牌子：休息室\n"

    :sys.replace_state(pid, fn state ->
      put_in(state.private.characters, [self()])
    end)

    busy = RoomOccupancyText.run(context, requester(%{}), %{config: config, room_id: looker_room})
    assert context_output(busy) == "门上挂了个牌子：休息中、请毋打扰\n"
  end

  test "RoomOccupancyText uses context.characters for the current room" do
    room_id = "test:current_occupancy"
    context = %Kalevala.World.Room.Context{data: %Room{id: room_id}, characters: [self()]}

    config = %{
      "kind" => "room_occupancy",
      "hidden" => "门上挂了个牌子：休息室",
      "shown" => "门上挂了个牌子：休息中、请毋打扰"
    }

    busy = RoomOccupancyText.run(context, requester(%{}), %{config: config, room_id: room_id})
    assert context_output(busy) == "门上挂了个牌子：休息中、请毋打扰\n"
  end

  test "lookup/2 resolves the player_skill (literacy) rooms" do
    for room <- [
          "xiakedao:shidong2",
          "xiakedao:shidong4",
          "xiakedao:shidong7",
          "xiakedao:shidong10"
        ] do
      assert ItemDescHandlers.lookup(room, "player_skill") == {:ok, {PlayerSkill, :run}}
    end
  end

  test "PlayerSkill shows the literate text when the skill meets the threshold" do
    context = %Kalevala.World.Room.Context{data: %Room{}}

    literate = PlayerSkill.run(context, requester_with_skill(1), %{config: @bi_config})
    assert context_output(literate) == "识字者看到的蝌蚪文。\n"
  end

  test "PlayerSkill shows the illiterate text below the threshold" do
    context = %Kalevala.World.Room.Context{data: %Room{}}

    illiterate = PlayerSkill.run(context, requester_with_skill(0), %{config: @bi_config})
    assert context_output(illiterate) == "文盲看到的壁画。\n"
  end

  test "lookup/2 resolves the player_skill (family-gated) room" do
    assert ItemDescHandlers.lookup("xiyu:houdong", "player_skill") ==
             {:ok, {PlayerSkill, :run}}
  end

  test "PlayerSkill shows the special text when family matches and skill meets the threshold" do
    context = %Kalevala.World.Room.Context{data: %Room{}}

    got = PlayerSkill.run(context, requester_with_family("星宿派", 160), %{config: @pet_config})
    assert context_output(got) ==
             "上面刻有金蜈蚣，黑寡妇，赤蝎子，千年灵蛇，花斑毒蟾。你心中一惊：“难道这便是五圣剧毒？”\n"
  end

  test "PlayerSkill shows the plain text when the player is not in the required family" do
    context = %Kalevala.World.Room.Context{data: %Room{}}

    got = PlayerSkill.run(context, requester_with_family("少林派", 200), %{config: @pet_config})
    assert context_output(got) == "上面刻有蜈蚣，蜘蛛，蝎子，蛇，蟾蜍五种毒物。\n"
  end

  test "PlayerSkill shows the plain text when skill is below threshold even if family matches" do
    context = %Kalevala.World.Room.Context{data: %Room{}}

    got = PlayerSkill.run(context, requester_with_family("星宿派", 100), %{config: @pet_config})
    assert context_output(got) == "上面刻有蜈蚣，蜘蛛，蝎子，蛇，蟾蜍五种毒物。\n"
  end



  test "lookup/2 resolves the room_temp_tiers room" do
    assert ItemDescHandlers.lookup("hengyang:outzigai1", "room_temp_tiers") ==
             {:ok, {RoomTempTiers, :run}}
  end

  test "RoomTempTiers returns the default when no room temp is set" do
    context = %Kalevala.World.Room.Context{data: %Room{}}
    assert context_output(RoomTempTiers.run(context, requester(%{}), %{config: @bi_tiers_config})) ==
             "这块石壁看起来很坚实。\n"
  end

  test "RoomTempTiers prefers the matching temp tier" do
    context = %Kalevala.World.Room.Context{data: %Room{state: %{"marks/推" => 1}}}

    assert context_output(RoomTempTiers.run(context, requester(%{}), %{config: @bi_tiers_config})) ==
             "石门已经被推开了，却露出一个山洞来。\n"
  end

  test "RoomTempTiers yields to the earlier tier when several are set" do
    context = %Kalevala.World.Room.Context{data: %Room{state: %{"marks/破" => 1, "marks/推" => 1}}}

    assert context_output(RoomTempTiers.run(context, requester(%{}), %{config: @bi_tiers_config})) ==
             "石壁已经被打破了。\n"
  end

  test "PlayerTempBranch requires the player temp before revealing anything" do
    context = %Kalevala.World.Room.Context{data: %Room{id: "fuzhou:mishi"}}

    denied =
      PlayerTempBranch.run(context, requester(%{}), %{
        config: @liang_config,
        room_id: "fuzhou:mishi"
      })

    assert context_output(denied) == "你要看什么？\n"
    assert denied.events == []
  end

  test "PlayerTempBranch sets the follow-up temp when the room flag is absent" do
    context = %Kalevala.World.Room.Context{data: %Room{id: "fuzhou:mishi"}}

    revealed =
      PlayerTempBranch.run(context, requester(%{"marks/辟1" => 1}), %{
        config: @liang_config,
        room_id: "fuzhou:mishi"
      })

    assert context_output(revealed) == "一根楠木做的房梁，可惜年代太久，已经腐烂得不成样子了。\n"

    assert [
             {pid, %{topic: "character/effects", data: %{effects: [{:set_temp, "marks/辟2", 1}]}}}
           ] = revealed.events

    assert pid == self()
  end

  test "PlayerTempBranch shows the moved text when the room flag is set" do
    context = %Kalevala.World.Room.Context{
      data: %Room{id: "fuzhou:mishi", state: %{"move" => 1}}
    }

    moved =
      PlayerTempBranch.run(context, requester(%{"marks/辟1" => 1}), %{
        config: @liang_config,
        room_id: "fuzhou:mishi"
      })

    assert context_output(moved) == "一根楠木做的房梁，上面有崭新的刮痕，似乎不久前才有人动过。\n"
    assert moved.events == []
  end

  test "lookup/2 resolves the arena_state (leitai) room" do
    assert ItemDescHandlers.lookup("city:leitai", "arena_state") ==
             {:ok, {ArenaState, :run}}
  end

  test "ArenaState renders the open text when the arena is not closed" do
    room_id = "test:leitai_open"
    on_exit(fn -> Arena.open(room_id) end)
    Arena.open(room_id)

    context = %Kalevala.World.Room.Context{data: %Room{id: room_id}}

    assert context_output(
             ArenaState.run(context, requester(%{}), %{config: @tiaofu_config, room_id: room_id})
           ) == "本擂台现在自由开放。\n"
  end

  test "ArenaState interpolates the closer's name into the closed text" do
    room_id = "test:leitai_closed"
    on_exit(fn -> Arena.open(room_id) end)
    Arena.open(room_id)

    context = %Kalevala.World.Room.Context{data: %Room{id: room_id}}

    # 默认（未关闭）→ 开放文本
    assert context_output(
             ArenaState.run(context, requester(%{}), %{config: @tiaofu_config, room_id: room_id})
           ) == "本擂台现在自由开放。\n"

    # 关闭后 → 把 {name} 替换为关闭者的名字
    Arena.close(room_id, %{name: "张三"})

    assert context_output(
             ArenaState.run(context, requester(%{}), %{config: @tiaofu_config, room_id: room_id})
           ) == "本擂台现在被 张三 暂时关闭。\n"
  end

  @tag :finger_d
  test "lookup/2 resolves the 16 gate rooms to the FINGER_D killer handler" do
    for room <- [
          "chengdu:eastgate",
          "chengdu:northgate",
          "chengdu:southgate",
          "chengdu:westgate",
          "city:beimen",
          "city:dongmen",
          "city:nanmen",
          "city:ximen",
          "lanzhou:beimen",
          "lanzhou:dongmen",
          "lanzhou:nanmen",
          "lanzhou:ximen",
          "suzhou:beimen",
          "suzhou:dongmen",
          "suzhou:nanmen",
          "suzhou:ximen"
        ] do
      assert ItemDescHandlers.lookup(room, "finger_d_killer") ==
               {:ok, {FingerDKiller, :run}}
    end
  end

  @tag :finger_d
  test "FingerDKiller appends the per-city footer to the notice board" do
    context = %Kalevala.World.Room.Context{data: %Room{id: "city:beimen"}}

    output =
      context_output(
        FingerDKiller.run(context, requester(%{}), %{config: @gaoshi_config, room_id: "city:beimen"})
      )

    # 无论当前有无通缉犯，落款（footer）一定被拼到正文后面
    assert output =~ "成都提督"
    assert output =~ "吴天德"
    # 正文要么「治安良好」要么「缉拿以下人犯」，二者必居其一
    assert output =~ ~r/^(本城治安良好|现在本城正在缉拿以下人犯)/u
  end

  @tag :finger_d
  test "FingerDKiller renders wanted killers from the FINGER_D registry" do
    name = "通缉犯_#{System.unique_integer([:positive])}"
    on_exit(fn -> FingerD.clear_killer(name) end)
    FingerD.mark_killer(name)

    context = %Kalevala.World.Room.Context{data: %Room{id: "chengdu:eastgate"}}

    output =
      context_output(
        FingerDKiller.run(context, requester(%{}), %{config: @gaoshi_config, room_id: "chengdu:eastgate"})
      )

    # 通缉名单里出现了被 mark 的名字，且落款仍在
    assert output =~ name
    assert output =~ "现在本城正在缉拿以下人犯"
    assert output =~ "成都提督"
  end

  @tag :finger_d
  test "FingerD.get_killer_text/0 is fail-safe and returns a string" do
    # 不假设共享 ETS 的空/非空状态（async 下其它测试可能并发 mark），
    # 只验证返回值是字符串、且内容要么是治安良好、要么是缉拿名单。
    text = FingerD.get_killer_text()
    assert is_binary(text)
    assert text =~ ~r/^(本城治安良好|现在本城正在缉拿以下人犯)/u
  end

  @tag :gaoshi_visitor
  test "lookup/2 resolves city:guangchang to the gaoshi_visitor handler" do
    assert ItemDescHandlers.lookup("city:guangchang", "gaoshi_visitor") ==
             {:ok, {GaoshiVisitor, :run}}
  end

  @tag :gaoshi_visitor
  test "GaoshiVisitor renders the 扬州府通告 banner with the seeded visitor count" do
    room_id = "city:guangchang"

    context =
      %Kalevala.World.Room.Context{
        data: %Room{id: room_id, state: %{"visitor" => 365}}
      }

    output =
      context_output(
        GaoshiVisitor.run(context, requester(%{}), %{
          config: @gaoshi_visitor_config,
          room_id: room_id
        })
      )

    # 关键标点与中文数字必须出现
    assert output =~ "扬州府通告"
    assert output =~ "近期共有"
    assert output =~ "三百六十五"
    assert output =~ "人通过此地"

    # 顶/底边框为 65 个 *，且整段以换行收尾（与 LPC look_gaoshi 逐字一致）
    assert String.starts_with?(output, "\n" <> String.duplicate("*", 65) <> "\n")
    assert String.ends_with?(output, String.duplicate("*", 65) <> "\n")
  end

  @tag :gaoshi_visitor
  test "GaoshiVisitor falls back to 零 when the visitor count is absent" do
    room_id = "city:guangchang"
    context = %Kalevala.World.Room.Context{data: %Room{id: room_id}}

    output =
      context_output(
        GaoshiVisitor.run(context, requester(%{}), %{
          config: @gaoshi_visitor_config,
          room_id: room_id
        })
      )

    assert output =~ "近期共有零人通过此地"
  end

  @tag :pig_table
  test "lookup/2 解析四间拱猪房到 pig_table handler" do
    for room <- ["city:eproom", "city:nproom", "city:sproom", "city:wproom"] do
      assert ItemDescHandlers.lookup(room, "table") ==
               {:ok, {PigTable, :run}}
    end
  end

  @tag :pig_table
  test "PigTable 空桌：四个座位均空，给出 sit 提示" do
    room_id = "city:eproom"
    context =
      %Kalevala.World.Room.Context{
        data: %Room{
          id: room_id,
          state: %{
            "pig_phase" => "initting",
            "pig_north" => "",
            "pig_west" => "",
            "pig_south" => "",
            "pig_east" => "",
            "pig_server" => ""
          }
        }
      }

    output =
      context_output(
        PigTable.run(context, requester(%{}), %{
          config: @pig_table_config,
          room_id: room_id
        })
      )

    assert output =~ "这是一张专门用于拱猪的四方桌。"
    assert output =~ "北边的椅子是空的。 想玩可用 sit north 坐上去。"
    assert output =~ "西边的椅子是空的。 想玩可用 sit west 坐上去。"
    assert output =~ "南边的椅子是空的。 想玩可用 sit south 坐上去。"
    assert output =~ "东边的椅子是空的。 想玩可用 sit east 坐上去。"
  end

  @tag :pig_table
  test "PigTable 已有玩家坐下：显示座位玩家名，桌长标注 (桌长)" do
    room_id = "city:nproom"
    context =
      %Kalevala.World.Room.Context{
        data: %Room{
          id: room_id,
          state: %{
            "pig_phase" => "initting",
            "pig_north" => "",
            "pig_west" => "张三",
            "pig_south" => "李四",
            "pig_east" => "",
            "pig_server" => "张三"
          }
        }
      }

    # 未坐玩家（pigging_seat 为空）
    output =
      context_output(
        PigTable.run(context, requester(%{}), %{
          config: @pig_table_config,
          room_id: room_id
        })
      )

    assert output =~ "北边的椅子是空的。"
    assert output =~ "西边的椅子上坐的是：张三(桌长)。"
    assert output =~ "南边的椅子上坐的是：李四。"
    assert output =~ "东边的椅子是空的。"

    # 坐在 south 位的玩家再看一次（视角不影响座位状态视图）
    output_south =
      context_output(
        PigTable.run(context, requester(%{"pigging_seat" => "south"}), %{
          config: @pig_table_config,
          room_id: room_id
        })
      )

    assert output_south =~ "南边的椅子上坐的是：李四。"
  end

  test "Pull sets the room temp and reports state" do
    room_id = "test:furong1"
    start_supervised!({FakeRoom, room_id})

    opened = Pull.run(%Conn{}, %{trailing: "net", room_id: room_id})
    assert conn_output(opened) == "\n你把蜘蛛网拉了下来。\n"
    assert Room.get_state_by_id(room_id, "marks/拉") == 1

    again = Pull.run(%Conn{}, %{trailing: "net", room_id: room_id})
    assert conn_output(again) == "蜘蛛网已经被拉破了。\n"

    invalid = Pull.run(%Conn{}, %{trailing: "wall", room_id: room_id})
    assert conn_output(invalid) == "你要拉什么？\n"
  end

  test "Zigaihole Move toggles the room temp" do
    room_id = "test:zigaihole"
    start_supervised!({FakeRoom, room_id})

    opened = Move.run(%Conn{}, %{trailing: "desk", room_id: room_id})
    assert conn_output(opened) == "\n你用力一推，石桌下面竟露出一个坑(keng)来。\n\n"
    assert Room.get_state_by_id(room_id, "marks/移") == 1

    closed = Move.run(%Conn{}, %{trailing: "石桌", room_id: room_id})
    assert conn_output(closed) == "\n你用力一推，将石桌移回了原处。\n\n"
    assert Room.get_state_by_id(room_id, "marks/移") == nil

    invalid = Move.run(%Conn{}, %{trailing: "bed", room_id: room_id})
    assert conn_output(invalid) == "你想移什么？\n"
  end

  defp requester(temp) do
    %{pid: self(), meta: %PlayerMeta{temp: temp}}
  end

  defp requester_with_score(score) do
    %{pid: self(), meta: %PlayerMeta{stats: %Stats{score: score}}}
  end

  defp requester_with_skill(level) do
    %{pid: self(), meta: %PlayerMeta{stats: %Stats{skills: %{"literate" => level}}}}
  end

  defp requester_with_family(family_name, level) do
    %{
      pid: self(),
      meta: %PlayerMeta{
        family: %{name: family_name},
        stats: %Stats{skills: %{"xingxiu-qishu" => level}}
      }
    }
  end

  defp run_score(context, score, config) do
    context
    |> ScoreTiers.run(requester_with_score(score), %{config: config})
    |> context_output()
  end

  defp context_output(%{output: output}) do
    Enum.map_join(output, fn {_pid, %{data: data}} -> data end)
  end

  defp conn_output(%Conn{output: output}) do
    Enum.map_join(output, & &1.data)
  end
end
