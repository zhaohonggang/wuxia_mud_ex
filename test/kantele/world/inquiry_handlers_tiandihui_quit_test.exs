defmodule Kantele.World.InquiryHandlersTiandihuiQuitTest do
  @moduledoc """
  #831 天地会陈近南 ask_tuihui：party/party_name 门控 + 退会清 party/rank/level。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kantele.Character.Party
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.InquiryHandlers.TiandihuiQuit

  @config %{
    "kind" => "tiandihui_quit",
    "party_name" => "天地会",
    "not_member_msg" => "陈近南笑了笑，对{name}说道：你还没加入我天地会呢，退什么退？\n",
    "look_msg" => "{npc}看了看{name}。",
    "sigh_msg" => "{npc}叹了口气。",
    "quit_say" => "反清复明，就要坚贞志士，你去吧! "
  }

  defp player(opts \\ []) do
    env =
      Keyword.get(opts, :env, %{
        "party/party_name" => "天地会",
        "party/rank" => "青木堂香主",
        "party/level" => 1,
        "detach" => "旧门派"
      })

    %Conn{
      character: %Character{
        id: Keyword.get(opts, :id, "player:test"),
        name: "测试玩家",
        room_id: "beijing:qingmu_dating",
        meta: %PlayerMeta{env: env, marks: %{}}
      },
      private: %Conn.Private{channel_changes: []},
      output: [],
      session: %{}
    }
  end

  defp data(opts \\ []) do
    %{
      asker_id: Keyword.get(opts, :asker_id, "player:test"),
      asker_name: "测试玩家",
      npc_name: "陈近南",
      npc_room_id: "beijing:qingmu_dating",
      perform_name: Keyword.get(opts, :perform_name, "退会")
    }
  end

  defp updated(conn), do: Map.get(conn.private || %{}, :update_character) || conn.character

  defp publishes(conn) do
    Enum.filter(conn.private.channel_changes, fn
      {:publish, "rooms:" <> _, _, _, _} -> true
      _ -> false
    end)
    |> Enum.map(fn {:publish, _channel, event, _options, _fun} -> event.data.text end)
  end

  test "非天地会成员：只广播原拒绝文案，不触动任何 party 键" do
    conn = player(env: %{"party/party_name" => "丐帮", "party/rank" => "长老"})

    result = TiandihuiQuit.run(conn, @config, data())

    assert publishes(result) == [
             "陈近南笑了笑，对测试玩家说道：你还没加入我天地会呢，退什么退？\n"
           ]

    assert Party.name(updated(result)) == "丐帮"
    assert updated(result).meta.env["party/rank"] == "长老"
  end

  test "从未入会：同样走非成员分支" do
    conn = player(env: %{})

    result = TiandihuiQuit.run(conn, @config, data())

    assert publishes(result) == [
             "陈近南笑了笑，对测试玩家说道：你还没加入我天地会呢，退什么退？\n"
           ]
  end

  test "天地会成员：look → sigh → say，随后清 party/rank/level 并保留其它 env" do
    result = TiandihuiQuit.run(player(), @config, data())

    # Conn.publish_message 把新事件放在 channel_changes 头部，故反转后读出发言顺序。
    assert publishes(result) |> Enum.reverse() == [
             "陈近南看了看测试玩家。\n",
             "陈近南叹了口气。\n",
             "陈近南说道：反清复明，就要坚贞志士，你去吧! \n"
           ]

    character = updated(result)
    assert Party.name(character) == nil
    refute Map.has_key?(character.meta.env, "party/rank")
    refute Map.has_key?(character.meta.env, "party/level")
    refute Map.has_key?(character.meta.env, "party")
    assert character.meta.env["detach"] == "旧门派"
  end

  test "非提问者事件静默忽略" do
    conn = player()
    result = TiandihuiQuit.run(conn, @config, data(asker_id: "player:other"))

    assert result == conn
    assert publishes(result) == []
  end

  test "Party.name 兼容扁平键与 LPC 整体 mapping；quit 清两套键" do
    conn = player(env: %{})
    character = %{
      meta: %{env: %{"party" => %{"party_name" => "天地会", "rank" => "会众", "level" => 1}}}
    }

    set = Party.set(conn.character, "天地会", "会众", 1)
    assert Party.name(set) == "天地会"
    assert Party.name(character) == "天地会"

    quit = Party.quit(set)
    assert Party.name(quit) == nil
    assert Party.quit_keys() == [
             "party/party_name",
             "party/rank",
             "party/level",
             "party",
             "rank",
             "level"
           ]
  end
end
