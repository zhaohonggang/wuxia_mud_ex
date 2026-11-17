defmodule Kantele.Character.ShaolinPromotionTest do
  @moduledoc """
  少林辈分晋升（#633–#635）两端测试。

  覆盖 LPC `qing.h`/`dao.h`/`cheng.h`/`hui.h`/`xuan.h`/`du.h` 的关键链路：
  达摩令 → fight_ok → accept_fight → checking → 推荐信；推荐信 → apprentice_ok；
  UCL 六个辈分 master_generation / 发信 / 改名配置已落到 NPC meta。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance
  alias Kantele.Character.GiveEvent
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.ShaolinPromotionEvent
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Items
  alias Kantele.World.Loader

  @ling "shaolin:damo_ling"
  @letter1 "shaolin:tuijianxin_1"

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(ExVenture.Repo)

    added =
      for id <- [@ling, @letter1], Items.get(id) == {:error, :not_found} do
        Items.put(id, %Item{
          id: id,
          name: if(id == @ling, do: "达摩令", else: "推荐信"),
          verbs: [],
          callback_module: Kantele.World.Item,
          meta: %Kantele.World.Item.Meta{}
        })

        id
      end

    on_exit(fn -> Enum.each(added, &Items.delete/1) end)
    :ok
  end

  defp npc_conn(accept_rules \\ []) do
    %Conn{
      character: %Kalevala.Character{
        id: "player:qingfa",
        name: "清法比丘",
        room_id: "shaolin:guangchang1",
        pid: self(),
        inventory: [],
        meta: %NonPlayerMeta{
          zone_id: "clone_lib",
          accept: accept_rules,
          vitals: Vitals.new(),
          stats: Stats.new(),
          combat: Kantele.Character.Combat.new()
        }
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp player_conn(item_id, temp \\ %{}, extra_inventory \\ []) do
    inst = %Instance{
      id: "inst-#{:erlang.unique_integer([:monotonic])}",
      item_id: item_id,
      created_at: DateTime.utc_now()
    }

    extra =
      Enum.map(extra_inventory, fn iid ->
        %Instance{
          id: "inst-#{:erlang.unique_integer([:monotonic])}",
          item_id: iid,
          created_at: DateTime.utc_now()
        }
      end)

    meta = %PlayerMeta{
      vitals: Vitals.new(),
      stats: Stats.new(),
      combat: Kantele.Character.Combat.new(),
      temp: temp,
      env: %{gender: "男性"},
      family: %{name: "少林派", generation: 41, class: "bonze"}
    }

    conn = %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "虚龙",
        room_id: "shaolin:guangchang1",
        inventory: [inst | extra],
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }

    {conn, inst}
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character

  defp out_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "accept_object 规则分发" do
    test "给达摩令 → ShaolinPromotionAccept 发 shaolin_promotion/give" do
      rule = %{
        kind: "shaolin_promotion",
        id: @ling,
        action: "duel",
        master_generation: 40,
        award_item: @letter1
      }

      conn = npc_conn([rule])
      {_player, inst} = player_conn(@ling)

      _conn =
        GiveEvent.receive(conn, %Event{
          topic: "characters/give",
          data: %{
            item_instance: inst,
            item_name: "达摩令",
            from_name: "虚龙",
            from_id: "player:test",
            reply_to: self()
          }
        })

      assert_receive %Event{topic: "shaolin_promotion/give", data: ev}, 1000
      assert ev.rule == rule
      assert ev.item_id == @ling
      refute_receive %Event{topic: "give/result"}, 300
    end
  end

  describe "玩家侧 give 回执" do
    test "达摩令：generation 匹配 → 置 fight_ok、销毁令、回执 fight_ok=true" do
      rule = %{action: "duel", master_generation: 40, award_item: @letter1}
      {conn, inst} = player_conn(@ling)

      _conn =
        ShaolinPromotionEvent.give(conn, %Event{
          topic: "shaolin_promotion/give",
          data: %{
            rule: rule,
            item_id: @ling,
            instance_id: inst.id,
            from_id: "player:test",
            npc_name: "清法比丘",
            reply_to: self()
          }
        })

      assert_receive %Event{topic: "shaolin_promotion/give-result", data: ev}, 1000
      assert ev.ok == true
      assert ev.fight_ok == true
    end

    test "达摩令：已持推荐信 → 拒绝且不置 fight_ok" do
      rule = %{action: "duel", master_generation: 40, award_item: @letter1}
      {conn, inst} = player_conn(@ling, %{"have_letter" => 1}, [@letter1])

      _conn =
        ShaolinPromotionEvent.give(conn, %Event{
          topic: "shaolin_promotion/give",
          data: %{
            rule: rule,
            item_id: @ling,
            instance_id: inst.id,
            from_id: "player:test",
            npc_name: "清法比丘",
            reply_to: self()
          }
        })

      assert_receive %Event{topic: "shaolin_promotion/give-result", data: ev}, 1000
      assert ev.ok == false
      assert ev.text =~ "拿我的推荐信去拜师了吗"
    end

    test "推荐信：have_letter → apprentice_ok=1" do
      rule = %{action: "letter", require_flag: "have_letter", set_flag: "apprentice_ok"}
      {conn, inst} = player_conn(@letter1, %{"have_letter" => 1})

      _conn =
        ShaolinPromotionEvent.give(conn, %Event{
          topic: "shaolin_promotion/give",
          data: %{
            rule: rule,
            item_id: @letter1,
            instance_id: inst.id,
            from_id: "player:test",
            npc_name: "道尘禅师",
            reply_to: self()
          }
        })

      assert_receive %Event{topic: "shaolin_promotion/give-result", data: ev}, 1000
      assert ev.ok == true
      assert ev.text =~ "你愿意拜我为师吗"
      refute Map.has_key?(ev, :fight_ok)
    end
  end

  describe "NPC 侧 accept_fight" do
    test "give-result 带 fight_ok → NPC 记下击败标记" do
      conn = npc_conn()

      conn1 =
        ShaolinPromotionEvent.npc_give_result(conn, %Event{
          topic: "shaolin_promotion/give-result",
          data: %{
            ok: true,
            fight_ok: true,
            from_id: "player:test",
            from_name: "虚龙",
            npc_name: "清法比丘",
            room_id: "shaolin:guangchang1",
            text: "好，既然已得到方丈许可，我们就来验证一下武功。"
          }
        })

      flag = "shaolin_promotion/fight_ok/player:test"
      assert Map.get(current(conn1).meta.temp, flag) == 1
    end

    test "accept_fight 有标记 → 消费标记并排 1 拍 checking" do
      conn = npc_conn()
      flag = "shaolin_promotion/fight_ok/player:test"
      meta = %{conn.character.meta | temp: Map.put(conn.character.meta.temp || %{}, flag, 1)}
      conn = %{conn | character: %{conn.character | meta: meta}}

      rule = %{kind: "shaolin_promotion", award_item: @letter1}

      conn1 =
        ShaolinPromotionEvent.accept_fight(conn, %Event{
          topic: "shaolin_promotion/accept-fight",
          data: %{player_id: "player:test", rule: rule}
        })

      refute Map.get(current(conn1).meta.temp, flag) == 1
      assert_receive %Event{topic: "npc/call-out", data: %{function: :checking}}, 2_000
    end
  end

  describe "UCL 辈分配置（ Loader ）" do
    test "六辈师父的 master_generation / 推荐信 / 改名前缀全部落地" do
      world = Loader.load()

      expectations = [
        {"清法比丘", 40, nil, nil},
        {"道尘禅师", 39, @letter1, "清"},
        {"澄观", 37, "shaolin:tuijianxin_3", "慧"},
        {"玄悲大师", 36, "shaolin:tuijianxin_4", "澄"}
      ]

      for {name, gen, letter, rename} <- expectations do
        npc = Enum.find(world.characters, &(&1.name == name))
        assert npc != nil, "找不到 #{name}"
        assert npc.meta.apprentice.master_generation == gen
        assert npc.meta.apprentice.rename_prefix == rename

        rules = Enum.filter(npc.meta.accept || [], &(&1.kind == "shaolin_promotion"))

        cond do
          is_nil(letter) ->
            assert Enum.any?(rules, &(&1.action == "duel" and &1.award_item == @letter1))

          rename == "澄" ->
            assert Enum.any?(rules, &(&1.id == letter and &1.action == "letter"))

          true ->
            assert Enum.any?(rules, &(&1.id == letter and &1.action == "letter"))
        end
      end
    end
  end
end
