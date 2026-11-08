defmodule Kantele.Character.ComeCommandTest do
  @moduledoc """
  `come <野兽>` 对 LPC `cmds/std/come.c` 的逐门回归。

  门控顺序：自己在战斗 → 驭兽术 >= 10 → 无 comedby → 参数 → present →
  userp → race → 野兽打架 → 野兽忙 → 有主 → 别人的（反扑）→ 自己 →
  living → 精力 → 扣精 / comedby / set_leader。
  """

  use ExUnit.Case, async: false

  alias Kantele.Character.BeastFixtures, as: F
  alias Kantele.Character.BeastState
  alias Kantele.Character.ComeCommand
  alias Kantele.Character.Commands

  setup do
    F.setup_beast_state()
    on_exit(fn -> BeastState.reset() end)
    :ok
  end

  defp run(p, params, opts \\ []), do: ComeCommand.run(F.build(p, opts), params)
  defp text(conn), do: F.output_text(conn)

  describe "LPC 门控（按源码顺序）" do
    test "自己在战斗中，先于其它门拒绝" do
      p = F.player(enemies: [%{id: "x", pid: self(), name: "敌", room_id: F.room_id()}])
      assert text(run(p, %{})) =~ "一边打架一边驯兽"
    end

    test "驭兽术 < 10" do
      assert text(run(F.player(training: 9), %{})) =~ "驭兽术还不纯熟，无法让野兽跟随你"
    end

    test "已有 comedby" do
      p = F.player(temp: %{"comedby" => "test:huangbiaoma"})
      assert text(run(p, %{})) =~ "已经有野兽跟着你了"
    end

    test "无参数 / 空白参数" do
      assert text(run(F.player(), %{})) =~ "你要让什么野兽跟随你？"
      assert text(run(F.player(), %{"target" => " "})) =~ "你要让什么野兽跟随你？"
    end

    test "房间里找不到目标" do
      assert text(run(F.player(), %{"target" => "黄骠马"})) =~ "这里没有这只野兽吧？"
    end

    test "目标是玩家" do
      other = F.other_player()
      assert text(run(F.player(), %{"target" => "李四"}, characters: [other])) =~ "人家也是玩家"
    end

    test "race 不是野兽" do
      npc = F.beast(name: "店小二", attributes: %{"race" => "人类"})
      assert text(run(F.player(), %{"target" => "店小二"}, characters: [npc])) =~ "这不是野兽"
    end

    test "野兽正在打架" do
      b = F.beast()
      F.set_state(b.id, %{owner_id: "player-1", enemies: ["x"]})
      assert text(run(F.player(), %{"target" => "黄骠马"}, characters: [b])) =~ "正在打架"
    end

    test "野兽正在忙" do
      b = F.beast()
      F.set_state(b.id, %{owner_id: "player-1", busy: 1})
      assert text(run(F.player(), %{"target" => "黄骠马"}, characters: [b])) =~ "正在忙乎"
    end

    test "无主野兽必须先 train" do
      b = F.beast()
      assert text(run(F.player(), %{"target" => "黄骠马"}, characters: [b])) =~ "是只无主野兽"
    end

    test "别人的野兽会反扑" do
      b = F.beast()
      F.set_state(b.id, %{owner_id: "player-2"})
      conn = run(F.player(), %{"target" => "黄骠马"}, characters: [b])
      assert text(conn) =~ "早被人家驯服了，你不是找死啊"
      assert_received {:beast_retaliate, "test:huangbiaoma"}
    end

    test "目标就是自己" do
      me = F.player()
      self_npc = F.beast(id: me.id, attributes: %{"race" => "野兽"})
      F.set_state(self_npc.id, %{owner_id: me.id})
      assert text(run(me, %{"target" => me.id}, characters: [self_npc])) =~ "自己跟自己"
    end

    test "野兽已晕倒" do
      b = F.beast(attributes: %{"not_living" => true})
      F.set_state(b.id, %{owner_id: "player-1"})
      assert text(run(F.player(), %{"target" => "黄骠马"}, characters: [b])) =~ "这只野兽晕倒了"
    end

    test "精力不足" do
      b = F.beast()
      F.set_state(b.id, %{owner_id: "player-1"})
      assert text(run(F.player(jing: 1), %{"target" => "黄骠马"}, characters: [b])) =~
               "现在你太累了"
    end
  end

  describe "成功分支" do
    test "扣精、写 comedby、set_leader(me)" do
      b = F.beast()
      F.set_state(b.id, %{owner_id: "player-1"})

      conn = run(F.player(), %{"target" => "huangbiaoma"}, characters: [b])

      assert text(conn) =~ "一窜就跟上了"
      refute text(conn) =~ "暂未开放"
      assert F.jing(conn) == 410
      assert F.comedby(conn) == b.id
      assert BeastState.get(b.id).leader_id == "player-1"
    end
  end

  describe "路由" do
    test "带参 come 把目标交给 run/2" do
      assert {:ok, parsed} = Commands.parse("come 黄骠马")
      assert parsed.module == ComeCommand
      assert parsed.params["target"] == "黄骠马"
    end

    test "裸 come 仍命中" do
      assert {:ok, parsed} = Commands.parse("come")
      assert parsed.module == ComeCommand
    end
  end
end
