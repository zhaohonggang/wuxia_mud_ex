defmodule Kantele.World.DuanMaijingGiveItemTest do
  @moduledoc """
  #844 段正明 `ask_maijing1/2` 两本脉经多状态给书定向测试。

  逐条覆盖 LPC duanzm.c:345-451：门派 → 师父 → 侠义 → 经验 → 经络学上限
  → owner 遍历四分支 → NPC say + give。第二本的门限与书本身 skill.max_skill 不同，
  两份数据都按 LPC 分别保留。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.GiveItem
  alias Kantele.World.Items
  alias Kantele.World.Loader

  setup_all do
    world = Loader.load()
    npc = Enum.find(world.characters, &(&1.name == "段正明")) || raise "段正明 not found"

    case Items.start_link(name: Items) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    for id <- ["clone_lib:jingluoxue1", "clone_lib:jingluoxue2"] do
      item = Enum.find(world.items, &(&1.id == id)) || raise "#{id} not found"
      Items.put(id, item)
    end

    %{
      world: world,
      first: npc.meta.inquiries["王叔和脉经"] || raise("王叔和脉经 inquiry not found"),
      second: npc.meta.inquiries["玉颧神脉经"] || raise("玉颧神脉经 inquiry not found")
    }
  end

  defp conn(opts \\ []) do
    meta = %PlayerMeta{
      vitals: %Vitals{qi: 100},
      stats: %Stats{
        combat_exp: Keyword.get(opts, :exp, 10_000),
        shen: Keyword.get(opts, :shen, 10_000),
        skills: %{"jingluo-xue" => Keyword.get(opts, :skill, 100)}
      },
      family: %{
        name: Keyword.get(opts, :family, "段氏皇族"),
        master_id: Keyword.get(opts, :master_id, "npc:duanzm")
      }
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "测试玩家",
        room_id: "dali:qiandian",
        inventory: [],
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: [],
      session: %{}
    }
  end

  defp data(owner \\ nil) do
    base = %{
      asker_id: "player:test",
      asker_name: "测试玩家",
      npc_id: "npc:duanzm",
      npc_name: "段正明",
      npc_pid: self(),
      npc_room_id: "dali:qiandian",
      remaining: 1
    }

    if is_nil(owner), do: base, else: Map.put(base, :owner, owner)
  end

  defp output_text(conn) do
    conn.output
    |> Enum.map(fn
      %Conn.Text{data: data} -> data
      %Conn.EventText{text: %Conn.Text{data: data}} -> data
      _ -> ""
    end)
    |> Enum.join()
  end

  # Helpers.say/4 走 PubSub（conn.private.channel_changes），不写 conn.output。
  defp channel_texts(conn) do
    conn.private.channel_changes
    |> Enum.map(fn
      {:publish, _channel, %Kalevala.Event{data: %{text: text}}, _opts, _fun} -> text
      _ -> ""
    end)
    |> Enum.join()
  end

  describe "UCL 数据与物品定义" do
    test "两条脉经 inquiry 逐项落位，保留第二本 199 与书 250 的差异", ctx do
      assert ctx.first["kind"] == "give_item"
      assert ctx.first["item"] == "clone_lib:jingluoxue1"
      assert ctx.first["min_shen"] == 10_000
      assert ctx.first["min_combat_exp"] == 10_000
      assert ctx.first["max_skill_levels"] == %{"jingluo-xue" => 149}
      assert ctx.first["master_before_gates"] in [true, "true"]
      assert ctx.first["owner_check"] in [true, "true"]
      assert ctx.first["npc_say"] == "这本脉经你就拿去看吧，可要认真研读。"
      assert ctx.first["silent_success"] in [true, "true"]

      assert ctx.second["item"] == "clone_lib:jingluoxue2"
      assert ctx.second["min_shen"] == 80_000
      assert ctx.second["min_combat_exp"] == 300_000
      assert ctx.second["max_skill_levels"] == %{"jingluo-xue" => 199}

      book1 = Enum.find(ctx.world.items, &(&1.id == "clone_lib:jingluoxue1"))
      book2 = Enum.find(ctx.world.items, &(&1.id == "clone_lib:jingluoxue2"))
      assert book1.meta.book.max_skill == 149
      assert book1.meta.book.exp_required == 10_000
      assert book1.meta.book.jing_cost == 80
      assert book2.meta.book.min_skill == 149
      assert book2.meta.book.max_skill == 250
      assert book2.meta.book.exp_required == 600_000
      assert book2.meta.book.jing_cost == 90
    end
  end

  describe "王叔和脉经门序" do
    test "门派门先于师父/侠义/经验门", %{first: cfg} do
      result =
        GiveItem.run(conn(family: "武当派", shen: 0, exp: 0, skill: 0), cfg, data())

      assert output_text(result) =~ "你又不是我们段家的传人，这话是什么意思？"
    end

    test "师父门先于侠义门", %{first: cfg} do
      result =
        GiveItem.run(conn(master_id: "other", shen: 0, exp: 0, skill: 0), cfg, data())

      assert output_text(result) =~ "…嗯…等你成为我的弟子后再说吧。"
      refute output_text(result) =~ "侠义正事做得不够"
    end

    test "侠义 → 经验 → 经络学上限逐门命中", %{first: cfg} do
      assert GiveItem.run(conn(shen: 9_999), cfg, data())
             |> output_text() =~ "你侠义正事做得不够，这脉经我不能给你。"

      assert GiveItem.run(conn(shen: 10_000, exp: 9_999), cfg, data())
             |> output_text() =~ "你现在经验太浅，不用忙着去阅读脉经。"

      assert GiveItem.run(conn(skill: 150), cfg, data())
             |> output_text() =~ "你对经络学的了解已经很透彻，远胜脉经中所述。"
    end

    test "经络学上限门先于 owner 门", %{first: cfg} do
      owner = %{kind: :asker, name: "测试玩家"}
      result = GiveItem.run(conn(skill: 150), cfg, data(owner))
      assert output_text(result) =~ "你对经络学的了解已经很透彻"
      refute output_text(result) =~ "不就是你拿着在看吗"
    end
  end

  describe "owner 遍历四分支" do
    test "owner 是玩家本人", %{first: cfg} do
      owner = %{kind: :asker, name: "测试玩家"}
      result = GiveItem.run(conn(), cfg, data(owner))
      assert output_text(result) =~ "我那本王叔和脉经不就是你拿着在看吗？"
    end

    test "owner 非角色（借出/容器）", %{first: cfg} do
      owner = %{kind: :object, name: "木箱"}
      result = GiveItem.run(conn(), cfg, data(owner))
      assert output_text(result) =~ "…嗯…脉经现在不在我手里。"
    end

    test "owner 是段氏同门", %{first: cfg} do
      owner = %{kind: :character, name: "段正淳", family: "段氏皇族"}
      result = GiveItem.run(conn(), cfg, data(owner))
      assert output_text(result) =~ "那书现在暂时是你兄弟段正淳在看，你要用就去找他吧。"
    end

    test "owner 是外人", %{first: cfg} do
      owner = %{kind: :character, name: "张无忌", family: "武当派"}
      result = GiveItem.run(conn(), cfg, data(owner))
      assert output_text(result) =~ "我那本脉经现在落在了张无忌手中，你去找他索回吧。"
    end
  end

  describe "发放成功" do
    test "王叔和脉经：只广播 NPC say，不重复私发返回值", %{first: cfg} do
      result = GiveItem.run(conn(), cfg, data(%{kind: :npc, name: "段正明"}))
      assert channel_texts(result) =~ "段正明说道：这本脉经你就拿去看吧，可要认真研读。"
      assert output_text(result) == ""
    end

    test "玉颧神脉经：80000/300000/199 通过后发放", %{second: cfg} do
      result =
        GiveItem.run(
          conn(shen: 80_000, exp: 300_000, skill: 199),
          cfg,
          data(%{kind: :npc, name: "段正明"})
        )

      assert channel_texts(result) =~ "段正明说道：这本脉经你就拿去看吧，可要认真研读。"
      assert output_text(result) == ""
    end
  end
end
