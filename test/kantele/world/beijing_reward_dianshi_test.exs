defmodule Kantele.World.BeijingRewardDianshiTest do
  @moduledoc """
  A-5-c C4：康熙领赏问询 + 殿试 answer 链。

  LPC 源：`d/beijing/npc/kangxi.c:55-113`（ask_reward）/ `115-196`（do_answer）、
  `63-87`（词池 216 项含重复权重）、`121-140`（ob_list 18 项含重复权重）。

  入侵守护进程状态用 `:sys.replace_state/2` 直改（测试环境不开真实波次）。
  """

  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.World.Item, as: ItemDef
  alias Kantele.Character.AnswerCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat
  alias Kantele.Communication
  alias Kantele.NPC.KangxiWords
  alias Kantele.World.InquiryHandlers
  alias Kantele.World.InquiryHandlers.BeijingReward
  alias Kantele.World.Items
  alias Kantele.World.Invasion

  @ob_ids [
    "clone_lib:linghui1",
    "clone_lib:linghui1",
    "clone_lib:lingzhi1",
    "clone_lib:lingzhi2",
    "clone_lib:full1",
    "clone_lib:full1",
    "clone_lib:xuelian1",
    "clone_lib:xuelian2",
    "clone_lib:neili1",
    "clone_lib:neili2",
    "clone_lib:renshen1",
    "clone_lib:renshen2",
    "clone_lib:va1",
    "clone_lib:va2",
    "clone_lib:va3",
    "clone_lib:va4",
    "clone_lib:va5",
    "clone_lib:va6"
  ]

  @ob_defs %{
    "clone_lib:linghui1" => {"昊天果", "枚"},
    "clone_lib:lingzhi1" => {"百年灵芝", "株"},
    "clone_lib:lingzhi2" => {"千年灵芝", "株"},
    "clone_lib:full1" => {"活骨灵药", "粒"},
    "clone_lib:xuelian1" => {"天山雪莲", "株"},
    "clone_lib:xuelian2" => {"千年雪莲", "株"},
    "clone_lib:neili1" => {"朱果", "枚"},
    "clone_lib:neili2" => {"火龙果", "枚"},
    "clone_lib:renshen1" => {"百年人参", "株"},
    "clone_lib:renshen2" => {"千年人参", "株"},
    "clone_lib:va1" => {"金块", "锭"},
    "clone_lib:va2" => {"翡翠", "块"},
    "clone_lib:va3" => {"玉石", "块"},
    "clone_lib:va4" => {"珍珠", "颗"},
    "clone_lib:va5" => {"玛瑙", "块"},
    "clone_lib:va6" => {"钻石", "颗"}
  }

  # ---- 词池 ----

  test "词池 216 项（LPC sizeof(w)），重复项保留权重" do
    assert KangxiWords.size() == 216

    counts = Enum.frequencies(KangxiWords.all())
    # kangxi.c:63-87 抽查重复项（不可去重）
    assert counts["国富"] == 2
    assert counts["保家"] == 3
    assert counts["为国"] == 4
    assert map_size(counts) == 181
  end

  test "词池全部为二字词，random/0 返回池内成员" do
    assert Enum.all?(KangxiWords.all(), fn w -> String.length(w) == 2 end)
    assert KangxiWords.random() in KangxiWords.all()
  end

  # ---- 问询 handler ----

  test "beijing_reward 已注册" do
    assert InquiryHandlers.lookup("beijing_reward") == BeijingReward
  end

  test "非问询者本人完全沉默" do
    conn =
      BeijingReward.run(build_conn(player()), %{"profile" => "kangxi"}, %{
        asker_id: "player:other"
      })

    assert output_text(conn) == ""
  end

  test "门1：康熙不在皇宫大殿 → 自嘲 + 移驾事件（npc/goto），不出题" do
    p = player()

    conn =
      BeijingReward.run(
        build_conn(p),
        %{"profile" => "kangxi"},
        %{
          asker_id: p.id,
          npc_name: "康熙大帝",
          npc_room_id: "beijing:tiananmen",
          npc_pid: self()
        }
      )

    assert output_text(conn) =~ "怪哉，朕如何不在皇宫！"
    assert_receive %Kalevala.Event{topic: "npc/goto", data: %{room_id: "beijing:hg"}}
    # 不出题：waidi 无 word
    refute Map.get(waidi(updated_char(conn)), :word)
  end

  test "门2：无入侵 record → 如今并无异族联军入侵呀！" do
    set_invasion!(born_time: nil, all_killed: false)
    p = player()

    conn = ask_kangxi_in_hg(p)

    assert output_text(conn) =~ "如今并无异族联军入侵呀！"
    refute Map.get(waidi(updated_char(conn)), :word)
  end

  test "门3：未全歼 → 朕并未恩准赏赐，尔等速速离去！" do
    set_invasion!(born_time: 1_700_000_001, all_killed: false)
    p = player(waidi: %{born_time: 1_700_000_001, number: 1})

    conn = ask_kangxi_in_hg(p)

    assert output_text(conn) =~ "朕并未恩准赏赐，尔等速速离去！"
    refute Map.get(waidi(updated_char(conn)), :word)
  end

  test "门4：waidi/born_time 过期 → 尔之赏赐已过期了！" do
    set_invasion!(born_time: 1_700_000_002, all_killed: true)
    p = player(waidi: %{born_time: 1_700_000_001, number: 1})

    conn = ask_kangxi_in_hg(p)

    assert output_text(conn) =~ "尔之赏赐已过期了！"
    refute Map.get(waidi(updated_char(conn)), :word)
  end

  test "成功链：三段 say + set waidi/word + 点阵谜面（16 行）" do
    set_invasion!(born_time: 1_700_000_001, all_killed: true)
    p = player(waidi: %{born_time: 1_700_000_001, number: 2})

    conn = ask_kangxi_in_hg(p)
    text = output_text(conn)

    assert text =~ "原来是抗击异族联军的义士，不错不错！"
    assert text =~ "但朕尚要出道殿试之题，看看你的文采若何。"
    assert text =~ "你看看朕写的这两个是什么字？(可用answer xxx 作答)"
    # 敬称按 rankd：缺省男性 20 岁 → 壮士
    assert text =~ "这位壮士杀敌勇猛"

    # 点阵谜面（LPC write(bitmap_font(word, 16) + "\n")）
    assert text =~ ~r/[8-]{16,}/

    # set("waidi/word", ...)：只写 word，保留 born_time/number
    waidi = waidi(updated_char(conn))
    assert Map.get(waidi, :word) in KangxiWords.all()
    assert Map.get(waidi, :born_time) == 1_700_000_001
    assert Map.get(waidi, :number) == 2
    assert Map.get(waidi, :npc_room_id) == "beijing:hg"
  end

  # ---- 殿试 answer ----

  test "殿试：无题时 passthrough（stub 回答系统文案）" do
    p = player()
    conn = AnswerCommand.run(build_conn(p), %{"rest" => "国富"})

    assert output_text(conn) =~ "回答系统目前不支持该选项。"
  end

  test "殿试门2：无 record → 如今并无异族联军入侵呀！" do
    set_invasion!(born_time: nil, all_killed: false)
    p = player(waidi: %{born_time: 1_700_000_001, number: 1, word: "国富", npc_name: "康熙大帝", npc_room_id: "beijing:hg"})

    conn = AnswerCommand.run(build_conn(p), %{"rest" => "国富"})

    assert output_text(conn) =~ "如今并无异族联军入侵呀！"
    # 未 delete waidi
    assert Map.get(waidi(updated_char(conn)), :word) == "国富"
  end

  test "殿试门4：born_time 过期 → 尔之赏赐已过期了！" do
    set_invasion!(born_time: 1_700_000_002, all_killed: true)
    p = player(waidi: %{born_time: 1_700_000_001, number: 1, word: "国富", npc_name: "康熙大帝", npc_room_id: "beijing:hg"})

    conn = AnswerCommand.run(build_conn(p), %{"rest" => "国富"})

    assert output_text(conn) =~ "尔之赏赐已过期了！"
    assert Map.get(waidi(updated_char(conn)), :word) == "国富"
  end

  test "殿试：空 arg → 你要回答什么?（半角问号，原文如此）" do
    set_invasion!(born_time: 1_700_000_001, all_killed: true)
    p = player(waidi: %{born_time: 1_700_000_001, number: 1, word: "国富", npc_name: "康熙大帝", npc_room_id: "beijing:hg"})

    conn = AnswerCommand.run(build_conn(p), %{"rest" => "  "})

    assert output_text(conn) =~ "你要回答什么?"
    assert Map.get(waidi(updated_char(conn)), :word) == "国富"
  end

  test "殿试：答错 → 两段 say + delete(waidi)" do
    set_invasion!(born_time: 1_700_000_001, all_killed: true)
    p = player(waidi: %{born_time: 1_700_000_001, number: 1, word: "国富", npc_name: "康熙大帝", npc_room_id: "beijing:hg"})

    conn = AnswerCommand.run(build_conn(p), %{"rest" => "民强"})
    text = output_text(conn)

    assert text =~ "虽然武艺出众,但是目不识丁，朕不能给你赏赐了。"
    assert text =~ "你还是速速离去吧！"
    # LPC me->delete("waidi")：整键删除
    assert waidi(updated_char(conn)) == %{}
  end

  test "殿试：答对 → 潜能/黄金/丹药发放 + 全服圣旨 + delete(waidi)" do
    set_invasion!(born_time: 1_700_000_001, all_killed: true)
    preload_ob_items()

    # 订阅 waidi 频道以捕获圣旨广播（LPC message("invasion", ..., users())）
    Communication.subscribe("waidi", [])

    p =
      player(
        waidi: %{
          born_time: 1_700_000_001,
          number: 3,
          word: "国富",
          npc_name: "康熙大帝",
          npc_room_id: "beijing:hg"
        }
      )

    conn = AnswerCommand.run(build_conn(p), %{"rest" => "国富"})
    text = output_text(conn)
    c = updated_char(conn)

    # pot = 100*3 + random(300) ∈ [300, 599]
    pot_gain = c.meta.stats.potential - p.meta.stats.potential
    assert pot_gain >= 300 and pot_gain <= 599

    assert text =~ "不但武艺出众,文采亦是不菲，朕要大大的赏赐于你。"

    # 圣旨潜能段（中文数字）与黄金段在广播里，见下方 edict 断言

    # 发放：黄金 + 一件 ob_list 丹药
    item_ids = Enum.map(c.inventory, & &1.item_id)
    assert "clone_lib:gold" in item_ids
    assert Enum.any?(item_ids, &(&1 in @ob_ids))

    # delete("waidi")
    assert waidi(c) == %{}

    # 圣旨广播到达 waidi 订阅者
    assert_receive %Kalevala.Event{
      topic: Kalevala.Event.Message,
      data: %{text: edict}
    }

    assert edict =~ "大内总管[Danei zongguan]：圣旨到！"
    # 黄金 gn = min(3 + random(2), 10) ∈ [3, 4]；潜能 pot ∈ [300, 599]（中文数字）
    assert edict =~ ~r/黄金(三|四)两/

    assert edict =~
             ~r/潜能(三百|三百[一二三四五六七八九十]+|四百|四百[一二三四五六七八九十]+|五百|五百[一二三四五六七八九十]+)点/

    assert edict =~ "钦此！"
  end

  # ---- helpers ----

  defp player(opts \\ []) do
    %Character{
      id: "player:dianshi-test",
      name: "张三",
      pid: self(),
      room_id: opts[:room_id] || "beijing:hg",
      inventory: [],
      attributes: %{},
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Combat.new(),
        env: if(opts[:waidi], do: %{waidi: opts[:waidi]}, else: %{})
      }
    }
  end

  defp ask_kangxi_in_hg(p) do
    BeijingReward.run(
      build_conn(p),
      %{"profile" => "kangxi"},
      %{
        asker_id: p.id,
        npc_name: "康熙大帝",
        npc_room_id: "beijing:hg",
        npc_pid: self()
      }
    )
  end

  defp set_invasion!(override) do
    pid = Process.whereis(Invasion)
    assert pid != nil, "Invasion GenServer 未随 app 启动"

    :sys.replace_state(pid, fn state -> Map.merge(state, Map.new(override)) end)
  end

  defp waidi(character) do
    character.meta.env |> Map.get(:waidi) || %{}
  end

  defp preload_ob_items do
    for {id, {name, unit}} <- @ob_defs do
      Items.put(id, %ItemDef{id: id, name: name, verbs: [], meta: %{"unit" => unit}})
    end

    Items.put("clone_lib:gold", %ItemDef{
      id: "clone_lib:gold",
      name: "黄金",
      verbs: [],
      meta: %{"unit" => "两"}
    })
  end

  defp output_text(conn) do
    private_text(conn) <> room_text(conn)
  end

  # 直发玩家的文本（write/谜面）
  defp private_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  # 房间广播（LPC command("say")/message_vision 走 channel_changes；
  # cons 顺序 → Enum.reverse 恢复先后）
  defp room_text(conn) do
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.flat_map(fn
      {:publish, _channel, event, _opts, _fun} ->
        [%{text: text} = _data] = [event.data]
        [text]

      _ ->
        []
    end)
    |> Enum.join("")
  end

  defp updated_char(conn), do: conn.private.update_character || conn.character

  # ---- C5：御前侍卫护送链（yuqian1.c:65-100 ask_reward） ----

  test "yuqian 门2：无入侵 record → say 如今并无异族联军入侵呀！" do
    preload_ob_items()
    set_invasion!(born_time: nil)
    p = player(room_id: "beijing:wgc")
    conn = run_yuqian(p)

    assert output_text(conn) =~ "如今并无异族联军入侵呀！"
  end

  test "yuqian 门3：未全歼 → say 圣上并未恩准赏赐，尔等速速离去！" do
    preload_ob_items()
    set_invasion!(exists: true, all_killed: false, born_time: 1_700_000_001)
    p = player(room_id: "beijing:wgc")
    conn = run_yuqian(p)

    assert output_text(conn) =~ "圣上并未恩准赏赐，尔等速速离去！"
  end

  test "yuqian 门4：born_time 过期 → say 你的赏赐已经过期了！" do
    preload_ob_items()
    set_invasion!(exists: true, all_killed: true, born_time: 1_700_000_002)
    p = player(room_id: "beijing:wgc", waidi: %{born_time: 1_700_000_001})
    conn = run_yuqian(p)

    assert output_text(conn) =~ "你的赏赐已经过期了！"
  end

  test "yuqian 门5：玩家已在皇宫 → say 你快快向皇上领赏吧！" do
    preload_ob_items()
    set_invasion!(exists: true, all_killed: true, born_time: 1_700_000_001)
    p = player(room_id: "beijing:hg", waidi: %{born_time: 1_700_000_001})
    conn = run_yuqian(p)

    assert output_text(conn) =~ "你快快向皇上领赏吧！"
  end

  test "yuqian 门1：killer condition → 静默（无任何输出）" do
    preload_ob_items()
    set_invasion!(exists: true, all_killed: true, born_time: 1_700_000_001)
    p = player(room_id: "beijing:wgc", waidi: %{born_time: 1_700_000_001})
    conn = build_conn(p)
    conn = %{conn | session: Map.put(conn.session || %{}, "conditions", %{"killer" => 500})}

    conn = run_yuqian(p, conn)

    assert output_text(conn) == ""
  end

  test "yuqian 护送链：两段 say + vision → 玩家移宫 → npc/goto×2 → say + vision×2" do
    preload_ob_items()
    set_invasion!(exists: true, all_killed: true, born_time: 1_700_000_001)
    p = player(room_id: "beijing:wgc", waidi: %{born_time: 1_700_000_001})
    conn = run_yuqian(p)

    text = output_text(conn)

    assert text =~ "啊，原来是抗击异族联军的义士，快请快请！"
    assert text =~ "在下这便带你入宫面见圣上！"
    assert text =~ "大步地走进皇宫大殿"
    assert text =~ "好了，我带你到大殿了，你可以面见圣上领赏了。"
    assert text =~ "头也不回地离去了。"
    assert text =~ "急匆匆的走了过来。"

    # 玩家已移至皇宫大殿（LPC me->move("/d/beijing/hg")）
    c = updated_char(conn)
    assert c.room_id == "beijing:hg"

    # 侍卫两次 npc/goto：先入宫、再回原房间（自进程收事件验证顺序）
    assert_receive %Kalevala.Event{topic: "npc/goto", data: %{room_id: "beijing:hg"}}
    assert_receive %Kalevala.Event{topic: "npc/goto", data: %{room_id: "beijing:wgc"}}
  end

  defp run_yuqian(p, conn \\ nil) do
    conn = conn || build_conn(p)

    BeijingReward.run(
      conn,
      %{"profile" => "yuqian"},
      %{
        asker_id: p.id,
        asker_name: p.name,
        npc_name: "御前侍卫",
        npc_room_id: "beijing:wgc",
        npc_pid: self()
      }
    )
  end
end
