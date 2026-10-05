defmodule Kantele.Npc.AttitudeTest do
  use ExUnit.Case, async: true

  alias Kantele.Npc.Attitude

  # LPC 里 attitude 决定的是「被挑战/攻击/杀时接不接」，**不是**是否主动攻击。
  # 语义与分支逐条对照 inherit/char/npc.c 的 accept_fight / accept_hit / accept_kill。

  describe "accept_fight —— 气血 >= 75%" do
    test "friendly 拒战（怎么可能是你的对手）" do
      assert {:refuse, msg} = Attitude.decide_fight("friendly", 80, 80)
      assert msg =~ "对手"
    end

    test "aggressive / killer 接受" do
      assert {:engage, msg} = Attitude.decide_fight("aggressive", 80, 80)
      assert msg =~ "出招"

      assert {:engage, _} = Attitude.decide_fight("killer", 80, 80)
    end

    test "peaceful（默认分支）接受并奉陪" do
      assert {:engage, msg} = Attitude.decide_fight("peaceful", 80, 80)
      assert msg =~ "奉陪"
    end

    test "nil（没写 attitude）也走默认分支" do
      assert {:engage, _} = Attitude.decide_fight(nil, 80, 80)
    end
  end

  describe "accept_fight —— 气血 < 75%" do
    test "一律以疲惫拒战（LPC:92）" do
      for att <- ["friendly", "aggressive", "killer", "peaceful", "heroism", nil] do
        assert {:refuse, msg} = Attitude.decide_fight(att, 74, 80)
        assert msg =~ "疲惫"
      end
    end

    test "qi 够但 jing 不够也算疲惫（两个条件都要满足）" do
      assert {:refuse, _} = Attitude.decide_fight("aggressive", 80, 74)
    end
  end

  describe "accept_fight —— 已在交战中" do
    test "heroism 应战（npc.c:54）" do
      assert {:engage, msg} = Attitude.decide_fight("heroism", 60, 60, true)
      assert msg =~ "出招"
    end

    test "其余一律拒战，理由是「以多欺少」（npc.c:66）" do
      for att <- ["peaceful", "friendly", "aggressive", "killer", nil] do
        assert {:refuse, msg} = Attitude.decide_fight(att, 100, 100, true)
        assert msg =~ "欺人太甚"
      end
    end
  end

  describe "accept_hit —— 气血 >= 50%" do
    test "friendly 喊且慢但不开打" do
      assert {:engage, msg} = Attitude.decide_hit("friendly", 60, 60)
      assert msg =~ "且慢"
    end

    test "第一次挨打：aggressive 接招、默认喊且慢" do
      # LPC 用 random(t) > N 判翻脸，random(1) = 1：
      #   aggressive 阈值 >8 -> 1 > 8 不成立 -> 「接招吧！」
      #   默认      阈值 >7 -> 1 > 7 不成立 -> 「且慢！」
      # 真实 LPC 的 random(t) 未必恰好是 1（t 随挨打次数增长），
      # 阈值不同意味着翻脸难度不同；我们用确定性序列代替真随机以便测试。
      assert {:engage, m1} = Attitude.decide_hit("aggressive", 60, 60)
      assert m1 =~ "接招"

      assert {:engage, m3} = Attitude.decide_hit("peaceful", 60, 60)
      assert m3 =~ "且慢"
    end

    test "killer 阈值低（>2），挨两下就翻脸" do
      # rem(2*7,10) = 4 > 2 -> killer 翻脸杀人
      assert {:kill, m} = Attitude.decide_hit("killer", 60, 60, 2)
      assert m =~ "找死"
    end

    test "挨得够多次会翻脸杀人（attempt 大到 random(t) > N）" do
      # rem(7*7,10)=9 > 8 -> aggressive 翻脸
      assert {:kill, m1} = Attitude.decide_hit("aggressive", 60, 60, 7)
      assert m1 =~ "手正痒"

      # killer 阈值低（>2），attempt=1 时 rem(7,10)=7 > 2 已经成立
      assert {:kill, m2} = Attitude.decide_hit("killer", 60, 60, 1)
      assert m2 =~ "找死找到这里来了"

      # 默认分支阈值 >7，attempt=7 时 9 > 7 成立
      assert {:kill, m3} = Attitude.decide_hit("peaceful", 60, 60, 7)
      assert m3 =~ "找死"
    end
  end

  describe "accept_hit —— 气血 < 50%（被彻底激怒）" do
    test "三个分支一律反杀，且台词不同" do
      assert {:kill, m1} = Attitude.decide_hit("friendly", 40, 40)
      assert m1 =~ "不容情"

      assert {:kill, m2} = Attitude.decide_hit("aggressive", 40, 40)
      assert m2 =~ "找死"

      assert {:kill, m3} = Attitude.decide_hit("peaceful", 40, 40)
      assert m3 =~ "不仁"
    end

    test "refute 关键字确实没被误用 —— LPC accept_hit 从不拒战" do
      for att <- ["friendly", "aggressive", "killer", "peaceful", "heroism", nil] do
        refute match?({:refuse, _}, Attitude.decide_hit(att, 40, 40))
        refute match?({:refuse, _}, Attitude.decide_hit(att, 60, 60))
      end
    end
  end

  describe "accept_kill —— 一律接受，只换台词" do
    test "friendly / aggressive / killer / 默认 各有台词" do
      assert {:engage, m1} = Attitude.decide_kill("friendly")
      assert m1 =~ "不留情"

      assert {:engage, m2} = Attitude.decide_kill("aggressive")
      assert m2 =~ "忌日"

      assert {:engage, m3} = Attitude.decide_kill("killer")
      assert m3 =~ "忌日"

      assert {:engage, m4} = Attitude.decide_kill("peaceful")
      assert m4 =~ "一决生死"
    end

    test "被打到要杀人命时没有 attitude 会拒战" do
      for att <- ["friendly", "aggressive", "killer", "peaceful", "heroism", nil] do
        assert {:engage, _} = Attitude.decide_kill(att)
      end
    end
  end

  describe "辅助" do
    test "pct/2 正常与除零" do
      assert Attitude.pct(50, 100) == 50
      assert Attitude.pct(100, 100) == 100
      assert Attitude.pct(0, 100) == 0
      assert Attitude.pct(10, 0) == 100
    end

    test "proactive?/1 只作参考，不驱动主动攻击" do
      assert Attitude.proactive?("aggressive")
      assert Attitude.proactive?("killer")
      refute Attitude.proactive?("peaceful")
      refute Attitude.proactive?("friendly")
      refute Attitude.proactive?("heroism")
    end
  end
end