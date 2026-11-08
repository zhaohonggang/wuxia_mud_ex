defmodule Kantele.Character.StayCommandTest do
  @moduledoc """
  `stay` 对 LPC `cmds/std/stay.c`（源文件名 `ting.c`）的逐门回归。

  LPC 不收参数：用 `query_temp("comedby")` 里的野兽 id 回房间 `present()`
  找对象，再走 owner / 自己 / living / 打架四门，成功后删 `comedby`
  并 `set_leader(0)`。本端口按 `owner_id` 归一，不复刻 LPC 的对象/字符串
  混用 bug（见 `BeastTaming` moduledoc）。
  """

  use ExUnit.Case, async: false

  alias Kantele.Character.BeastFixtures, as: F
  alias Kantele.Character.BeastState
  alias Kantele.Character.Commands
  alias Kantele.Character.StayCommand

  setup do
    F.setup_beast_state()
    on_exit(fn -> BeastState.reset() end)
    :ok
  end

  defp run(p, opts \\ []), do: StayCommand.run(F.build(p, opts), %{})
  defp text(conn), do: F.output_text(conn)
  defp following(b), do: F.player(temp: %{"comedby" => b.id})

  describe "LPC 门控（按源码顺序）" do
    test "没有 comedby" do
      assert text(run(F.player())) =~ "已经没有野兽跟着你了"
    end

    test "自己在战斗中" do
      b = F.beast()
      p = F.player(temp: %{"comedby" => b.id}, enemies: [%{id: "x", pid: self()}])
      assert text(run(p)) =~ "一边打架一边驯兽"
    end

    test "跟随的野兽不在本房间" do
      b = F.beast()
      assert text(run(following(b))) =~ "这里没有这只野兽吧？"
    end

    test "无主野兽" do
      b = F.beast()
      assert text(run(following(b), characters: [b])) =~ "是只无主野兽"
    end

    test "被别人驯服会反扑" do
      b = F.beast()
      F.set_state(b.id, %{owner_id: "player-2"})
      conn = run(following(b), characters: [b])
      assert text(conn) =~ "是被人家驯服了，你不是找死啊"
      assert_received {:beast_retaliate, "test:huangbiaoma"}
    end

    test "目标就是自己" do
      me = F.player()
      self_npc = F.beast(id: me.id, attributes: %{"race" => "野兽"})
      F.set_state(self_npc.id, %{owner_id: me.id})
      p = F.player(temp: %{"comedby" => me.id})
      assert text(run(p, characters: [self_npc])) =~ "自己跟自己"
    end

    test "野兽已晕倒" do
      b = F.beast(attributes: %{"not_living" => true})
      F.set_state(b.id, %{owner_id: "player-1"})
      assert text(run(following(b), characters: [b])) =~ "这只野兽晕倒了"
    end

    test "野兽正在打架" do
      b = F.beast()
      F.set_state(b.id, %{owner_id: "player-1", enemies: ["x"]})
      assert text(run(following(b), characters: [b])) =~ "它正在大打出手"
    end
  end

  describe "成功分支" do
    test "删 comedby 并 set_leader(0)，主人关系保留" do
      b = F.beast()
      F.set_state(b.id, %{owner_id: "player-1", leader_id: "player-1"})

      conn = run(following(b), characters: [b])

      assert text(conn) =~ "点了点头"
      refute text(conn) =~ "暂未开放"
      assert F.comedby(conn) == nil

      state = BeastState.get(b.id)
      assert state.leader_id == nil
      assert state.owner_id == "player-1"
    end
  end

  describe "路由" do
    test "裸 stay 命中 StayCommand" do
      assert {:ok, parsed} = Commands.parse("stay")
      assert parsed.module == StayCommand
    end

    test "LPC help 里写着 stay <动物>，但 main() 不收参数；多余文字不影响" do
      conn = StayCommand.run(F.build(F.player()), %{"command" => "stay"})
      assert text(conn) =~ "已经没有野兽跟着你了"
    end
  end
end
