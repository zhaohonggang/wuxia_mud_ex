defmodule Kantele.Npc.EngageRuleTest do
  use ExUnit.Case, async: true

  alias Kantele.Npc.EngageRule

  defp meta(engage), do: %{engage: engage}

  describe "decide/3" do
    test "accept=false 的对应类型返回拒绝 + msg" do
      m =
        meta(%{
          fight: %{accept: false, msg: "小的不敢！"},
          hit: %{accept: true},
          kill: %{accept: true}
        })

      assert EngageRule.decide(m, "fight", "守卫") == {:deny, "小的不敢！\n"}
      assert EngageRule.decide(m, "hit", "守卫") == :allow
      assert EngageRule.decide(m, "kill", "守卫") == :allow
    end

    test "msg 缺失时用默认拒词（含目标名与类型差异化）" do
      m = meta(%{fight: %{accept: false}, kill: %{accept: false}, hit: %{accept: false}})

      assert EngageRule.decide(m, "fight", "江百胜") == {:deny, "江百胜摇了摇头，拒绝与你切磋。\n"}
      assert EngageRule.decide(m, "kill", "江百胜") == {:deny, "江百胜摇了摇头，道：“你要杀我？”\n"}
      assert EngageRule.decide(m, "hit", "江百胜") == {:deny, "江百胜避开你的攻击，喝道：动什么手！\n"}
    end

    test "无 engage 或类型无规则时放行" do
      assert EngageRule.decide(meta(nil), "fight", "x") == :allow
      assert EngageRule.decide(meta(%{fight: %{accept: true}}), "kill", "x") == :allow
      assert EngageRule.decide(%{}, "fight", "x") == :allow
    end
  end

  describe "engage_rule/2" do
    test "按字符串类型取子规则" do
      m = meta(%{fight: %{accept: false}, hit: %{accept: true}})
      assert EngageRule.engage_rule(m, "fight") == %{accept: false}
      assert EngageRule.engage_rule(m, "hit") == %{accept: true}
      assert EngageRule.engage_rule(m, "kill") == nil
    end
  end
end