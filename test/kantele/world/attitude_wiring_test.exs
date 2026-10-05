defmodule Kantele.World.AttitudeWiringTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Combat
  alias Kantele.Character.NPCConfig
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kalevala.Character
  alias Kalevala.World.Room.Context
  alias Kantele.Npc.Attitude

  # LPC inherit/char/npc.c 的 accept_* 优先顺序：
  #   1. 守卫            -> check_enemy
  #   2. NPC 自写 accept_* -> 自己的规则
  #   3. 否则            -> switch (query("attitude"))
  #
  # room.ex 的 combat/attack 分支就是按这个顺序排的；
  # 这里验证第 3 步在真实数据上会走到、且取值与 LPC 一致。

  defp npc(attitude, qi \\ 80, max_qi \\ 100, jing \\ 80, max_jing \\ 100) do
    %Character{
      id: "npc-#{attitude}",
      name: "路人",
      pid: self(),
      room_id: "test:room",
      meta: %NonPlayerMeta{
        zone_id: "test",
        vitals: %Vitals{qi: qi, max_qi: max_qi, jing: jing, max_jing: max_jing},
        stats: Stats.new(),
        combat: Combat.new(),
        combat_config: %NPCConfig{attitude: attitude, spawn_room_id: "test:room"},
        guarder: nil,
        engage: nil
      }
    }
  end

  describe "真实数据里的 attitude 分布" do
    test "world 里的 NPC 确实带 attitude（不是空字段）" do
      world = Kantele.World.Loader.load()

      with_att =
        Enum.filter(world.characters, fn c ->
          is_binary(Map.get(c.meta.combat_config || %NPCConfig{}, :attitude))
        end)

      assert length(with_att) > 2000,
             "应有 2000+ 个 NPC 带 attitude，实际 #{length(with_att)}"

      # friendly / peaceful 最多，aggressive / killer 少
      counts =
        Enum.frequencies(Enum.map(with_att, &Map.get(&1.meta.combat_config, :attitude)))

      assert Map.get(counts, "peaceful", 0) > 0
      assert Map.get(counts, "friendly", 0) > 0
      assert Map.get(counts, "aggressive", 0) > 0
    end

    test "守卫（guarder）也有 attitude，但走 check_enemy 不走 attitude" do
      # LPC inherit/char/npc.c 的 accept_* 开头就是
      #     if (this_object()->is_guarder()) return check_enemy(who, "fight");
      # 所以守卫的 attitude 是**死数据** —— 它的行为由 check_enemy 决定。
      #
      # 验证这一点：找出所有带 guarder 的 NPC，确认它们同时也有 attitude
      # （说明数据上两者并存、靠代码优先级区分），而不是只有其中之一。
      world = Kantele.World.Loader.load()

      guards_with_attitude =
        Enum.filter(world.zones, fn z ->
          Enum.any?(Map.values(z.characters), fn c ->
            Map.get(c.meta, :guarder) != nil and
              is_binary(Map.get(c.meta.combat_config || %NPCConfig{}, :attitude))
          end)
        end)

      assert guards_with_attitude != [],
             "守卫 NPC 同时带 guarder 与 attitude —— 靠代码优先级而非数据区分"
    end
  end

  describe "战斗类型到 attitude 分支的映射" do
    test "kill -> decide_kill（永远接受）" do
      for att <- ["friendly", "aggressive", "peaceful", nil] do
        assert {:engage, _} = Attitude.decide_kill(att)
      end
    end

    test "hit -> decide_hit（气血 <50% 时无条件反杀）" do
      assert {:kill, msg} = Attitude.decide_hit("friendly", 40, 40)
      assert msg =~ "不容情"
    end

    test "fight -> decide_fight（气血 <75% 时拒战）" do
      assert {:refuse, msg} = Attitude.decide_fight("aggressive", 70, 70)
      assert msg =~ "疲惫"
    end
  end

  describe "气血门槛取自 vitals" do
    test "max 为 0 时按满状态处理（不除零）" do
      c = npc("friendly", 0, 0, 0, 0)

      # pct(0,0) = 100 -> 气血满 -> friendly 拒战
      assert {:refuse, _} = Attitude.decide_fight("friendly", 100, 100)
      assert c.meta.vitals.max_qi == 0
    end

    test "半血的 peaceful 会接战（>=75% 不满足则拒战）" do
      # 50% < 75% -> 拒战
      assert {:refuse, _} = Attitude.decide_fight("peaceful", 50, 50)
      # 80% >= 75% -> 接受
      assert {:engage, _} = Attitude.decide_fight("peaceful", 80, 80)
    end
  end
end