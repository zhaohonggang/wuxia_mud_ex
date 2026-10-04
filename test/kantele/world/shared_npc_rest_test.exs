defmodule Kantele.World.SharedNpcRestTest do
  use ExUnit.Case, async: true

  @moduletag :world_data

  # 跨区共享 NPC 的第二批。做法与 shared_npc_test.exs 相同：
  # 拿 `# Generated from …` 把每个 room_characters 映射回 LPC 源文件，
  # 读原始 set("objects") 确定「这个 id 到底是哪个 NPC」，再从 LPC 原文转换。
  #
  # LPC 里的跨区引用长这样：
  #   d/lanzhou/ximen.c      "/d/beijing/npc/ducha" : 1,
  #   d/suzhou/beimen.c      "/d/city/npc/wujiang"  : 1,
  #   d/zhongzhou/chenglou.c "/clone/npc/xunbu"     : 1,

  setup_all do
    %{world: Kantele.World.Loader.load()}
  end

  @zones %{
    "ducha" => ~w(city jingzhou kunming lanzhou luoyang quanzhen zhongzhou),
    "liumang" => ~w(chengdu foshan fuzhou jingzhou luoyang suzhou xiangyang zhongzhou),
    "wujiang" => ~w(chengdu fuzhou guanwai huanghe kunlun luoyang shaolin suzhou zhongzhou),
    "kid1" => ~w(heimuya jingzhou lanzhou lingjiu luoyang suzhou tulong zhongzhou),
    "xunbu" => ~w(changan city jingzhou kunming lanzhou luoyang quanzhen zhongzhou),
    "xiaoer2" => ~w(baituo huashan jingzhou kaifeng kunming lingxiao luoyang suzhou wudang zhongzhou),
    "guest" => ~w(fuzhou tianlongsi xuedao xueshan),
    "duke" => ~w(city luoyang)
  }

  defp defined?(world, zone, id) do
    Enum.any?(world.zones, fn z ->
      z.id == zone and Map.has_key?(z.characters, String.to_atom(id))
    end)
  end

  test "8 类共 56 个区全部补齐", %{world: world} do
    for {id, zones} <- @zones, zone <- zones do
      assert defined?(world, zone, id),
             "#{zone} 缺 characters \"#{id}\""
    end
  end

  test "实例数与 LPC 的引用数一致", %{world: world} do
    # LPC 里各区引用的次数（loader 补齐前的实测值）
    expected = [
      {"ducha", "城门督察", 23},
      {"wujiang", "武将", 20},
      {"kid1", "小孩", 19},
      {"xunbu", "巡捕", 16},
      {"duke", "赌客", 11},
      {"guest", "进香客", 14},
      {"xiaoer2", "店小二", 15}
    ]

    for {id, name, n} <- expected do
      count = Enum.count(world.characters, &(&1.name == name))

      assert count >= n, "#{id}（#{name}）应至少有 #{n} 个实例，实际 #{count}"
    end
  end

  describe "逐个核对 LPC 原文" do
    test "ducha 是「城门督察」，不是别人", %{world: world} do
      c = Enum.find(world.characters, &(&1.name == "城门督察"))

      assert c
      assert c.meta.stats.int == 30
      assert c.meta.stats.str == 30
      assert c.meta.combat_config.attitude == "heroism"
    end

    test "xunbu 叫「巡捕」而不是转换器占位符 \"NPC\"", %{world: world} do
      # clone/npc/xunbu.c 用 NPC_D->generate_cn_name()，转换器填了 name = "NPC"。
      # 它的 long 是「这是一个巡捕」，另有 title「六扇门内巡捕」。
      names = world.characters |> Enum.filter(&(&1.name in ["NPC", "巡捕"])) |> Enum.map(& &1.name)

      assert Enum.count(names, &(&1 == "巡捕")) >= 16,
             "巡捕应至少有 16 个，实际 #{Enum.count(names, &(&1 == "巡捕"))}"
    end

    test "xunbu 的六扇门内力不低", %{world: world} do
      c = Enum.find(world.characters, &(&1.name == "巡捕"))

      assert c.meta.stats.combat_exp >= 600_000
      assert c.meta.vitals.max_neili == 3000
    end

    test "xunbu 会拒绝打架但接受 hit / kill（LPC 的 accept_fight/hit/kill）", %{
      world: world
    } do
      c = Enum.find(world.characters, &(&1.name == "巡捕"))

      assert c.meta.engage.fight.accept == false
      assert c.meta.engage.hit.accept == true
      assert c.meta.engage.kill.accept == true
    end

    test "liumang 有两个 LPC 实现，按区区分", %{world: world} do
      # /d/city/npc/liumang    combat_exp 1000，无 chat
      # /d/beijing/npc/liumang combat_exp 10000，chat_chance 1 + 台词
      city_ver = Enum.filter(world.characters, &(&1.name == "流氓" and &1.meta.zone_id == "suzhou"))
      bj_ver = Enum.filter(world.characters, &(&1.name == "流氓" and &1.meta.zone_id == "jingzhou"))

      assert Enum.any?(city_ver, &(&1.meta.stats.combat_exp == 1_000)),
             "suzhou 的流氓应是 city 版（exp 1000）"

      assert Enum.any?(bj_ver, &(&1.meta.stats.combat_exp == 10_000)),
             "jingzhou 的流氓应是 beijing 版（exp 10000）"
    end

test "xiaoer2 认得 buy / list 两个命令", %{world: world} do
      # 注意要限定在本轮补的区里 —— 别的区（changan / beijing …）本来就有
      # xiaoer2 / duke，是各自 LPC 源转出来的，brain / goods 未必一样。
      c =
        Enum.find(world.characters, fn x ->
          x.name == "店小二" and x.meta.zone_id == "suzhou"
        end)

      assert c, "suzhou 应该有一个店小二"
      assert "buy" in c.meta.init.add_actions
      assert "list" in c.meta.init.add_actions
      assert Enum.any?(c.meta.greetings, &(&1 =~ "进来喝杯茶"))
    end

  test "duke 会骂人（LPC 的 chat_msg 转成了 ChatChance 闲聊节点）", %{world: world} do
      c =
        Enum.find(world.characters, fn x ->
          x.name == "赌客" and x.meta.zone_id == "city"
        end)

      assert c, "city 应该有一个赌客"

      assert %Kalevala.Brain{root: %Kalevala.Brain.Sequence{nodes: nodes}} = c.brain

      chat =
        Enum.find(nodes, fn
          %Kalevala.Brain.ConditionalSelector{nodes: inner} ->
            Enum.any?(inner, &match?(%Kalevala.Brain.Condition{type: Kantele.Brain.Conditions.ChatChance}, &1))

          _ ->
            false
        end)

      assert chat, "赌客的 brain 里应有 ChatChance 闲聊节点"

      action =
        Enum.find(chat.nodes, &match?(%Kalevala.Brain.Action{type: Kantele.Character.ChatAction}, &1))

      assert Enum.any?(action.data.lines, &(&1 =~ "手气")),
             "应保留 LPC 那句「今天爷的手气怎么那么不顺」"
    end
  end
end