defmodule Kantele.Combat.PerformsTest do
  use ExUnit.Case, async: true

  alias Kantele.Combat.Performs
  alias Kantele.Combat.Skills.Performs.ChousuiZhang.Dan
  alias Kantele.Combat.Skills.Performs.HuashanJian.Jie

  describe "lookup/1" do
    test "按 perform_id 反查实现模块（skill-id/move）" do
      assert Performs.lookup("huashan-jian/jie") == Jie
      assert Performs.lookup("chousui-zhang/dan") == Dan
    end

    test "未注册或格式不合法返回 nil" do
      assert Performs.lookup("nope/none") == nil
      assert Performs.lookup("huashan-jian") == nil
      assert Performs.lookup("huashan-jian/nope") == nil
      assert Performs.lookup(nil) == nil
    end
  end

  describe "feedback/3" do
    test "攻击方存活：投递回执事件" do
      Performs.feedback(%{pid: self()}, 220, 2)

      assert_receive %Kalevala.Event{
        topic: "combat/perform-feedback",
        data: %{neili_cost: 220, busy: 2}
      }
    end

    test "攻击方已退出：静默不发" do
      pid = spawn(fn -> :ok end)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _}

      Performs.feedback(%{pid: pid}, 220, 2)
      refute_receive %Kalevala.Event{topic: "combat/perform-feedback"}, 50
    end
  end

  describe "resolve_incoming/5" do
    test "未注册 perform 原样返回 conn" do
      conn = %Kalevala.Character.Conn{}
      assert Performs.resolve_incoming(conn, "nope/none", %{}, %{}, %{}) == conn
    end
  end
end
