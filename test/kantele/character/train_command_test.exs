defmodule Kantele.Character.TrainCommandTest do
  @moduledoc """
  `train <野兽>` 对 LPC `cmds/std/train.c` 的逐门回归。

  门控顺序：驭兽术 >= 10 → 参数 → present → userp → race → 自己的 →
  别人的 → 自己 → living → 精力 → 随机成败 → 扣精/技能/清敌/登记主人。
  """

  # BeastState 是全局 ETS，写用例必须串行
  use ExUnit.Case, async: false

  alias Kantele.Character.BeastFixtures, as: F
  alias Kantele.Character.BeastState
  alias Kantele.Character.Commands
  alias Kantele.Character.Stats
  alias Kantele.Character.TrainCommand

  setup do
    F.setup_beast_state()
    on_exit(fn -> BeastState.reset() end)
    :ok
  end

  defp run(p, params, opts \\ []), do: TrainCommand.run(F.build(p, opts), params)
  defp text(conn), do: F.output_text(conn)

  describe "LPC 门控（按源码顺序）" do
    test "驭兽术 < 10 时先于参数检查拒绝" do
      conn = run(F.player(training: 9), %{})
      assert text(conn) =~ "驭兽术还不纯熟，无法训练野兽"
      refute text(conn) =~ "暂未开放"
    end

    test "无参数 / 空白参数" do
      assert text(run(F.player(), %{})) =~ "你要训练什么野兽？"
      assert text(run(F.player(), %{"target" => "   "})) =~ "你要训练什么野兽？"
    end

    test "房间里找不到目标" do
      assert text(run(F.player(), %{"target" => "黄骠马"})) =~ "这里没有这只野兽吧？"
    end

    test "目标是玩家（userp）" do
      other = F.other_player()
      conn = run(F.player(), %{"target" => "李四"}, characters: [other])
      assert text(conn) =~ "人家也是玩家"
    end

    test "race 不是野兽" do
      npc = F.beast(id: "test:dianxiaoer", name: "店小二", attributes: %{"race" => "人类"})
      conn = run(F.player(), %{"target" => "店小二"}, characters: [npc])
      assert text(conn) =~ "这不是野兽"
    end

    test "已经由自己驯服过" do
      b = F.beast()
      F.set_state(b.id, %{owner_id: "player-1"})
      conn = run(F.player(), %{"target" => "黄骠马"}, characters: [b])
      assert text(conn) =~ "就是你驯服过的"
    end

    test "已经被别人驯服" do
      b = F.beast()
      F.set_state(b.id, %{owner_id: "player-2"})
      conn = run(F.player(), %{"target" => "黄骠马"}, characters: [b])
      assert text(conn) =~ "早被人家驯服了"
    end

    test "目标就是自己" do
      me = F.player()
      # 用非 PlayerMeta 的同 id 快照穿过 userp/race 两门，才轮得到 ob == me
      self_npc = F.beast(id: me.id, attributes: %{"race" => "野兽"})
      conn = run(me, %{"target" => me.id}, characters: [self_npc])
      assert text(conn) =~ "把自己不当人"
    end

    test "野兽已晕倒（living）" do
      b = F.beast(attributes: %{"not_living" => true})
      conn = run(F.player(), %{"target" => "黄骠马"}, characters: [b])
      assert text(conn) =~ "这只野兽晕倒了"
    end

    test "精力不足（jing <= cost）" do
      b = F.beast()
      conn = run(F.player(jing: 1), %{"target" => "黄骠马"}, characters: [b])
      assert text(conn) =~ "现在你太累了"
    end
  end

  describe "随机失败分支" do
    test "失败：播报开头、野兽反扑、start_busy(1)、不登记主人也不扣精" do
      b = F.beast()
      me = F.player()

      conn =
        run(me, %{"target" => "黄骠马"},
          characters: [b],
          roll: fn _sp, _dp -> true end
        )

      assert text(conn) =~ "手脚乱摆"
      assert text(conn) =~ "野性不泯"
      refute text(conn) =~ "摇了摇尾巴"

      assert F.jing(conn) == 500
      assert F.updated(conn).meta.combat.busy == 1
      assert_received {:beast_retaliate, "test:huangbiaoma"}
      assert BeastState.get(b.id) == nil
    end
  end

  describe "成功分支" do
    test "扣精、清敌方、升驭兽术、登记 owner/attitude/ridable" do
      b = F.beast()
      me = F.player(enemies: [%{id: "enemy-1", pid: self(), name: "强盗", room_id: F.room_id()}])

      conn = run(me, %{"target" => "黄骠马"}, characters: [b])

      assert text(conn) =~ "手脚乱摆"
      assert text(conn) =~ "摇了摇尾巴"
      refute text(conn) =~ "暂未开放"

      # cost = max_jing / (training/10) - 10 = 200 / 2 - 10 = 90
      assert F.jing(conn) == 410
      assert F.updated(conn).meta.combat.enemies == []
      assert Stats.skill(F.updated(conn).meta.stats, "training") == 21

      state = BeastState.get(b.id)
      assert state.owner_id == "player-1"
      assert state.owner_name == "张三"
      assert state.attitude == "peace"
      assert state.enemies == []
      # 名字含「马」→ LPC set("ridable", 1)
      assert state.ridable == true
    end

    test "int 为 0 时不升技能（LPC improve_skill(training, random(int)) 加 0 点）" do
      b = F.beast()
      conn = run(F.player(int: 0), %{"target" => "黄骠马"}, characters: [b])
      assert Stats.skill(F.updated(conn).meta.stats, "training") == 20
    end

    test "非骑乘野兽不设 ridable" do
      b = F.beast(id: "test:dushe", name: "毒蛇")
      run(F.player(), %{"target" => "毒蛇"}, characters: [b])
      assert BeastState.get(b.id).ridable == false
    end
  end

  describe "路由" do
    test "带参 train 把整段文字交给 run/2" do
      assert {:ok, parsed} = Commands.parse("train 黄骠马")
      assert parsed.module == TrainCommand
      assert parsed.params["target"] == "黄骠马"
    end

    test "裸 train 仍命中" do
      assert {:ok, parsed} = Commands.parse("train")
      assert parsed.module == TrainCommand
    end
  end
end
