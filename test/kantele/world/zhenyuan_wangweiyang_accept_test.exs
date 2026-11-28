defmodule Kantele.World.ZhenyuanWangweiyangAcceptTest do
  @moduledoc """
  #834 王维扬 `accept_object`（LPC wangweiyang.c:616-702）：
  引荐信 inline 授「天刀八势」、厚背紫金刀归还分文案、其余物品拒收。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kalevala.World.Item.Instance
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Loader
  alias Kantele.World.ZhenyuanWangweiyangAccept, as: Accept

  defp instance(item_id \\ Accept.letter_id()) do
    %Instance{
      id: "zwy-inst-#{:erlang.unique_integer([:monotonic])}",
      item_id: item_id,
      created_at: DateTime.utc_now()
    }
  end

  defp player_conn(opts \\ []) do
    stats =
      Keyword.get(opts, :stats) ||
        %Stats{skills: %{}, performs: MapSet.new(), gongxian: 0}

    family = Keyword.get(opts, :family, %{})

    %Conn{
      character: %Character{
        id: Keyword.get(opts, :id, "player:test"),
        name: "测试玩家",
        room_id: "beijing:shufang",
        inventory: Keyword.get(opts, :inventory, []),
        meta: %PlayerMeta{stats: stats, vitals: Vitals.new(), family: family, env: %{}}
      },
      private: %Conn.Private{channel_changes: []},
      output: [],
      session: %{}
    }
  end

  defp npc_conn(opts \\ []) do
    %Conn{
      character: %Character{
        id: Keyword.get(opts, :npc_id, "zhenyuan_wangweiyang"),
        name: Keyword.get(opts, :npc_name, "王维扬"),
        room_id: "beijing:shufang",
        inventory: [],
        meta: %{}
      },
      private: %Conn.Private{channel_changes: []},
      output: [],
      session: %{}
    }
  end

  defp event(opts) do
    %{
      action: Keyword.get(opts, :action, "letter"),
      from_id: Keyword.get(opts, :from_id, "player:test"),
      from_name: "测试玩家",
      item_id: Keyword.get(opts, :item_id, Accept.letter_id()),
      instance_id: Keyword.get(opts, :instance_id, "zwy-inst"),
      npc_id: "zhenyuan_wangweiyang",
      npc_name: "王维扬",
      npc_room_id: "beijing:shufang"
    }
  end

  defp publishes(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn
      {:publish, "rooms:" <> _, _, _, _} -> true
      _ -> false
    end)
    |> Enum.map(fn {:publish, _channel, msg, _options, _fun} -> msg.data.text end)
  end

  defp out_text(conn) do
    conn.output
    |> Enum.map(fn
      %Conn.Text{data: data} -> IO.iodata_to_binary(data)
      _ -> ""
    end)
    |> Enum.join()
  end

  defp updated(conn), do: Map.get(conn.private, :update_character) || conn.character

  describe "UCL 配置" do
    test "王维扬 accept 三分支按 LPC 顺序落位" do
      world = Loader.load()

      npc =
        Enum.find(world.characters, fn c ->
          c.name == "王维扬" and c.room_id == "beijing:shufang"
        end) || raise "王维扬 not found"

      rules = npc.meta.accept || raise "accept rules not found"

      assert Enum.map(rules, & &1.kind) == [
               "zhenyuan_wangweiyang",
               "zhenyuan_wangweiyang",
               "any"
             ]

      assert Enum.map(rules, & &1.action) == ["letter", "houbei", nil]
      assert Enum.map(rules, & &1.id) == [Accept.letter_id(), Accept.houbei_id(), nil]
      assert List.last(rules).accept == false
      assert List.last(rules).fail_msg == ["你给我这种东西干什么？"]
    end
  end

  describe "拒收分支" do
    setup do
      if is_nil(Process.whereis(Kantele.World.Items)) do
        {:ok, _pid} = Kantele.World.Items.start_link(name: Kantele.World.Items)
      end

      junk = struct(Kalevala.World.Item, id: "test:trash", name: "垃圾")
      Kantele.World.Items.put(junk.id, junk)

      on_exit(fn ->
        if Process.whereis(Kantele.World.Items) do
          Kantele.World.Items.delete(junk.id)
        end
      end)

      %{junk: junk}
    end

    test "非信件非紫金刀：拒收并执行 LPC 原文案", %{junk: junk} do
      world = Loader.load()

      npc =
        Enum.find(world.characters, fn c ->
          c.name == "王维扬" and c.room_id == "beijing:shufang"
        end) || raise "王维扬 not found"

      conn = %Conn{
        character: %Character{
          id: "zhenyuan_wangweiyang",
          name: "王维扬",
          room_id: "beijing:shufang",
          inventory: [],
          meta: %{npc.meta | accept: npc.meta.accept}
        },
        private: %Conn.Private{channel_changes: []},
        output: [],
        session: %{}
      }

      inst = instance(junk.id)

      result =
        Kantele.Character.GiveEvent.receive(conn, %{
          data: %{
            item_instance: inst,
            from_name: "测试玩家",
            from_id: "player:test",
            reply_to: self()
          }
        })

      assert out_text(result) =~ "你给我这种东西干什么？"
      assert_receive %Event{topic: "give/result", data: %{ok: false}}, 1000
    end
  end

  describe "NPC 侧 receive" do
    test "命中引荐信规则 → 发 zhenyuan/wangweiyang_accept 事件" do
      conn = npc_conn()
      inst = instance()
      data = %{reply_to: self(), from_id: "player:test", from_name: "测试玩家"}

      result =
        Accept.handle(
          conn,
          conn.character,
          inst,
          data,
          "测试玩家",
          %{kind: "zhenyuan_wangweiyang", action: "letter", id: Accept.letter_id()}
        )

      assert_receive %Event{topic: "zhenyuan/wangweiyang_accept", data: ev}, 1000
      assert ev.action == "letter"
      assert ev.from_id == "player:test"
      assert ev.instance_id == inst.id
      assert ev.npc_name == "王维扬"
      assert ev.npc_room_id == "beijing:shufang"
      assert updated(result).id == "zhenyuan_wangweiyang"
    end
  end

  describe "玩家侧信件授艺" do
    test "未学会：nod → haha → say → message_sort(旁观版) → haha，随后 19 次提升 + 授 perform" do
      inst = instance()
      conn = player_conn(inventory: [inst])

      result = Accept.handle_player(conn, %{data: event(instance_id: inst.id)})

      # Conn.publish_message 头部插入，反转后读出发言顺序。
      assert publishes(result) |> Enum.reverse() == [
               "王维扬点了点头。\n",
               "王维扬「哈哈哈」大笑几声。\n",
               "王维扬说道：好，好！既然这样，我就传你这招「天刀八势」！\n",
               Accept.render_letter_sort(Accept.letter_sort(), "王维扬", "测试玩家"),
               "王维扬「哈哈哈」大笑几声。\n"
             ]

      text = out_text(result)
      assert text =~ "你学会了「天刀八势」。"
      # message_sort 的 me=玩家 版：$n = 王维扬，$N = 你。
      assert text =~ "王维扬微笑着点了点头，对你道：“你可知道何为「八卦」吗？”"
      refute text =~ "$n"
      refute text =~ "$N"

      character = updated(result)
      assert Stats.perform_known?(character.meta.stats, Accept.perform_id())
      assert Stats.skill(character.meta.stats, "force") == 3
      assert Stats.skill(character.meta.stats, "bagua-dao") == 3
      assert Stats.skill(character.meta.stats, "martial-cognize") == 1
      refute Enum.any?(character.inventory, &(&1.id == inst.id))
    end

    test "已学会：只 shake + shit，不重复授予也不改技能" do
      inst = instance()

      stats = %Stats{
        skills: %{"force" => 100},
        performs: MapSet.new([Accept.perform_id()])
      }

      conn = player_conn(inventory: [inst], stats: stats)

      result = Accept.handle_player(conn, %{data: event(instance_id: inst.id)})

      assert publishes(result) |> Enum.reverse() == [
               "王维扬摇了摇头。\n",
               "王维扬破口大骂：“Shit!!怎么又死了~~”\n"
             ]

      refute out_text(result) =~ "你学会了"
      character = updated(result)
      assert Stats.skill(character.meta.stats, "force") == 100
      refute Enum.any?(character.inventory, &(&1.id == inst.id))
    end
  end

  describe "玩家侧还刀" do
    test "嫡传：很好，很好！并销毁物品实例" do
      inst = instance(Accept.houbei_id())
      family = %{master_id: "zhenyuan_wangweiyang"}

      conn = player_conn(inventory: [inst], family: family)

      result =
        Accept.handle_player(
          conn,
          %{data: event(action: "houbei", item_id: Accept.houbei_id(), instance_id: inst.id)}
        )

      assert publishes(result) == ["王维扬说道：很好，很好！\n"]
      refute Enum.any?(updated(result).inventory, &(&1.id == inst.id))
    end

    test "非嫡传：多谢这位壮士将厚背紫金刀交回。" do
      inst = instance(Accept.houbei_id())
      conn = player_conn(inventory: [inst], family: %{master_id: "somebody_else"})

      result =
        Accept.handle_player(
          conn,
          %{data: event(action: "houbei", item_id: Accept.houbei_id(), instance_id: inst.id)}
        )

      assert publishes(result) == ["王维扬说道：多谢这位壮士将厚背紫金刀交回。\n"]
    end
  end

  describe "纯函数与边界" do
    test "message_sort 反向渲染：旁观版用玩家名，私有版用「你」" do
      text = Accept.letter_sort()

      observer = Accept.render_letter_sort(text, "王维扬", "测试玩家")
      private = Accept.render_letter_sort(text, "王维扬", "你")

      assert observer =~ "王维扬微笑着点了点头，对测试玩家道"
      assert private =~ "王维扬微笑着点了点头，对你道"
      refute observer =~ "$n"
      refute observer =~ "$N"
    end

    test "19 次 improve_skill 序列逐字匹配 LPC" do
      assert Accept.improve_skills() == [
               "force",
               "force",
               "force",
               "nei-bagua",
               "nei-bagua",
               "nei-bagua",
               "parry",
               "parry",
               "parry",
               "wai-bagua",
               "wai-bagua",
               "wai-bagua",
               "blade",
               "blade",
               "blade",
               "bagua-dao",
               "bagua-dao",
               "bagua-dao",
               "martial-cognize"
             ]
    end

    test "非赠予者事件静默忽略" do
      conn = player_conn()
      result = Accept.handle_player(conn, %{data: event(from_id: "player:other")})

      assert result == conn
      assert publishes(result) == []
    end
  end
end
