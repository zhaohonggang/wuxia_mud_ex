defmodule Kantele.World.NpcGreetingTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kantele.Character.MoveEvent
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Communication

  @room_id "test:greet-npc-#{System.unique_integer([:positive])}"

  setup_all do
    :ok = Communication.register("rooms:#{@room_id}", Kantele.RoomChannel, room_id: @room_id)
    :ok
  end

  setup do
    :ok =
      Communication.subscribe("rooms:#{@room_id}",
        character: %Kalevala.Character{id: "greet-sub", room_id: @room_id}
      )

    on_exit(fn ->
      Communication.unsubscribe("rooms:#{@room_id}",
        character: %Kalevala.Character{id: "greet-sub", room_id: @room_id}
      )
    end)

    :ok
  end

  defp zhuziliu_npc do
    %Kalevala.Character{
      id: "wuguan:zhuziliu",
      name: "朱子柳",
      pid: self(),
      room_id: @room_id,
      inventory: [],
      meta: %NonPlayerMeta{
        zone_id: "wuguan",
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp player_with_literate(level) do
    %Kalevala.Character{
      id: "player:1",
      name: "张三",
      pid: self(),
      room_id: @room_id,
      inventory: [],
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: %{Stats.new() | skills: %{"literate" => level}},
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp notice_event(player) do
    %Event{
      from_pid: self(),
      topic: Event.Movement.Notice,
      data: %Event.Movement.Notice{character: player, direction: :to, reason: :enter}
    }
  end

  test "识字不足的玩家进入：朱子柳劝学（{respect} 已替换）" do
    MoveEvent.notice(build_conn(zhuziliu_npc()), notice_event(player_with_literate(50)))

    assert_receive {:room_message, text}
    assert text =~ "学些知识"
    refute String.contains?(text, "{respect}")
  end

  test "识字>99 的玩家进入：朱子柳不问候（LPC return）" do
    MoveEvent.notice(build_conn(zhuziliu_npc()), notice_event(player_with_literate(100)))
    refute_receive {:room_message, _}, 100
  end

  defp wusantong_npc do
    %Kalevala.Character{
      id: "wuguan:wusantong",
      name: "武三通",
      pid: self(),
      room_id: @room_id,
      inventory: [],
      meta: %NonPlayerMeta{
        zone_id: "wuguan",
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp player_with_skills(skills) do
    %Kalevala.Character{
      id: "player:2",
      name: "李四",
      pid: self(),
      room_id: @room_id,
      inventory: [],
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: %{Stats.new() | skills: skills},
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  test "武三通：基本武功未满百 → 按序说两句" do
    MoveEvent.notice(build_conn(wusantong_npc()), notice_event(player_with_skills(%{})))

    assert_receive {:room_message, t1}
    assert_receive {:room_message, t2}
    assert t1 =~ "传授基本武功"
    assert t2 =~ "学学"
  end

  test "武三通：force/dodge/parry 均>99 → 不问候" do
    skills = %{"force" => 100, "dodge" => 100, "parry" => 100}
    MoveEvent.notice(build_conn(wusantong_npc()), notice_event(player_with_skills(skills)))
    refute_receive {:room_message, _}, 100
  end

  defp guanjia_npc(id) do
    %Kalevala.Character{
      id: "wuguan:#{id}",
      name: "管事",
      pid: self(),
      room_id: @room_id,
      inventory: [],
      meta: %NonPlayerMeta{
        zone_id: "wuguan",
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp player_job(job, inventory) do
    %Kalevala.Character{
      id: "player:3",
      name: "王五",
      pid: self(),
      room_id: @room_id,
      inventory: inventory,
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new(),
        temp: %{"job_name" => job}
      }
    }
  end

  test "管事：job_name 不符 → 不问候" do
    MoveEvent.notice(build_conn(guanjia_npc("guanjia1")), notice_event(player_job("锄草", [])))
    refute_receive {:room_message, _}, 100
  end

  test "管事：job 匹配但无工具 → 提示去东物品房领" do
    MoveEvent.notice(build_conn(guanjia_npc("guanjia1")), notice_event(player_job("劈柴", [])))

    assert_receive {:room_message, text}
    assert text =~ "你还没领工具"
  end

  test "管事：job 匹配且有对应工具 → 告知就在此作业" do
    inv = [%{item_id: "wuguan:items.chaidao"}]
    MoveEvent.notice(build_conn(guanjia_npc("guanjia1")), notice_event(player_job("劈柴", inv)))

    assert_receive {:room_message, text}
    assert text =~ "劈柴"
    assert text =~ "耶律大爷"
  end

  defp wuxiuwen_npc do
    %Kalevala.Character{
      id: "wuguan:wuxiuwen",
      name: "武修文",
      pid: self(),
      room_id: @room_id,
      inventory: [],
      meta: %NonPlayerMeta{
        zone_id: "wuguan",
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp player_temp(temp) do
    %Kalevala.Character{
      id: "player:4",
      name: "赵六",
      pid: self(),
      room_id: @room_id,
      inventory: [],
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new(),
        temp: temp
      }
    }
  end

  test "武修文：领了活计未发工具 → 提示来领工具" do
    MoveEvent.notice(
      build_conn(wuxiuwen_npc()),
      notice_event(player_temp(%{"job_name" => "劈柴"}))
    )

    assert_receive {:room_message, text}
    assert text =~ "领工具"
  end

  test "武修文：活计已完成 → 让还工具" do
    MoveEvent.notice(
      build_conn(wuxiuwen_npc()),
      notice_event(player_temp(%{"mark/劈完了" => 1}))
    )

    assert_receive {:room_message, text}
    assert text =~ "做完了"
  end

  test "武修文：工具已发过 → 不问候" do
    MoveEvent.notice(
      build_conn(wuxiuwen_npc()),
      notice_event(player_temp(%{"mark/工具" => 1, "job_name" => "劈柴"}))
    )

    refute_receive {:room_message, _}, 100
  end

  defp npc_of(id, name) do
    %Kalevala.Character{
      id: id,
      name: name,
      pid: self(),
      room_id: @room_id,
      inventory: [],
      meta: %NonPlayerMeta{
        zone_id: "x",
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp player_env_family(env, family) do
    %Kalevala.Character{
      id: "player:5",
      name: "孙七",
      pid: self(),
      room_id: @room_id,
      inventory: [],
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new(),
        env: env,
        family: family
      }
    }
  end

  test "凌飞雪：和尚(class=bonze) → 群玉楼两句 + 有客人来了" do
    MoveEvent.notice(
      build_conn(npc_of("changan:lingfeixue", "凌飞雪")),
      notice_event(player_env_family(%{gender: "男性"}, %{class: "bonze"}))
    )

    assert_receive {:room_message, t1}
    assert_receive {:room_message, t2}
    assert_receive {:room_message, t3}
    assert t1 =~ "群玉楼"
    assert t2 =~ "快请上楼"
    assert t3 =~ "有客人来了"
  end

  test "凌飞雪：女性 → 逛窑子一句 + 有客人来了" do
    MoveEvent.notice(
      build_conn(npc_of("changan:lingfeixue", "凌飞雪")),
      notice_event(player_env_family(%{gender: "女性"}, nil))
    )

    assert_receive {:room_message, t1}
    assert_receive {:room_message, t2}
    assert t1 =~ "逛窑子"
    assert t2 =~ "有客人来了"
  end

  test "李文秀：男性 → 叹气（emote）" do
    MoveEvent.notice(
      build_conn(npc_of("gaochang:liwenxiu", "李文秀")),
      notice_event(player_env_family(%{gender: "男性"}, nil))
    )

    assert_receive {:room_message, text}
    assert text =~ "叹了口气"
  end

  test "采花贼：星宿派 → 说逍遥洞一句" do
    MoveEvent.notice(
      build_conn(npc_of("xiyu:caihua", "采花贼")),
      notice_event(player_env_family(%{gender: "男性"}, %{name: "星宿派"}))
    )

    assert_receive {:room_message, text}
    assert text =~ "逍遥洞"
  end

  test "采花贼：非星宿派 → 不问候" do
    MoveEvent.notice(
      build_conn(npc_of("xiyu:caihua", "采花贼")),
      notice_event(player_env_family(%{gender: "男性"}, %{name: "少林派"}))
    )

    refute_receive {:room_message, _}, 100
  end

  test "书痴：恒说快请进" do
    MoveEvent.notice(
      build_conn(npc_of("changan:shuchi", "书痴")),
      notice_event(player_env_family(%{gender: "男性"}, nil))
    )

    assert_receive {:room_message, text}
    assert text =~ "快请进"
    refute String.contains?(text, "{respect}")
  end

  # ---- 妓院老鸨（太监被踢出门 / 和尚 / 女性 / 普通男客） ----

  defp laobao_npc do
    npc_of("luoyang:laobao", "老鸨婆")
  end

  test "老鸨：太监 → 辱骂 + 两条踢人视讯 + 收尾瞬移" do
    eunuch = player_env_family(%{gender: "无性"}, nil)

    assert {:say, lines, {:teleport, "luoyang:sroad5"}} =
             Kantele.World.NpcGreeting.greet(laobao_npc(), eunuch)

    assert length(lines) == 3
    assert Enum.at(lines, 0) =~ "就是不伺候太监"
    assert {:vision, kicked, nil, _pid} = Enum.at(lines, 1)
    assert kicked =~ "踢出门外"
    assert {:vision, landed, "luoyang:sroad5", _pid} = Enum.at(lines, 2)
    assert landed =~ "春月楼"
    assert landed =~ "两颗门牙"
  end

  test "老鸨：太监进门后收到 character/teleport 事件" do
    MoveEvent.notice(build_conn(laobao_npc()), notice_event(player_env_family(%{gender: "无性"}, nil)))

    assert_receive %Event{topic: "character/teleport", data: %{room_id: "luoyang:sroad5"}}
  end

  test "老鸨：和尚 → 两句光顾春月楼 + 一句客人来了" do
    MoveEvent.notice(
      build_conn(laobao_npc()),
      notice_event(player_env_family(%{gender: "男性"}, %{class: "bonze"}))
    )

    assert_receive {:room_message, t1}
    assert_receive {:room_message, t2}
    assert_receive {:room_message, t3}
    assert t1 =~ "光顾我们春月楼"
    assert t2 =~ "西藏喇嘛"
    assert t3 =~ "客人来了"
  end

  test "老鸨：女性 → 逛窑子 + 叹气 + 儿子 + 客人来了" do
    MoveEvent.notice(
      build_conn(laobao_npc()),
      notice_event(player_env_family(%{gender: "女性"}, nil))
    )

    assert_receive {:room_message, t1}
    assert_receive {:room_message, t2}
    assert_receive {:room_message, t3}
    assert_receive {:room_message, t4}
    assert t1 =~ "大姑娘也逛窑子"
    assert t2 =~ "叹了口气"
    assert t3 =~ "我儿子不在"
    assert t4 =~ "客人来了"
  end

  test "老鸨：普通男客 → 只有一句客人来了" do
    MoveEvent.notice(
      build_conn(laobao_npc()),
      notice_event(player_env_family(%{gender: "男性"}, nil))
    )

    assert_receive {:room_message, text}
    assert text =~ "客人来了"
    refute_receive {:room_message, _}, 100
  end

  test "韦春芳（丽春院）：太监 → 踢到 city:nandajie2，台词用「不伺太监」" do
    assert {:say, lines, {:teleport, "city:nandajie2"}} =
             Kantele.World.NpcGreeting.greet(
               npc_of("city:wei", "韦春芳"),
               player_env_family(%{gender: "无性"}, nil)
             )

    assert Enum.at(lines, 0) =~ "不伺太监"
    assert {:vision, landed, "city:nandajie2", _} = Enum.at(lines, 2)
    assert landed =~ "丽春院"
  end

  # ---- 见人就杀的门卫 ----

  test "瓦耳拉齐：身上有 map → 喝道并开战" do
    map_item = %Kalevala.World.Item{
      id: "gaochang:items.map",
      name: "高昌迷宫地图",
      meta: %{aliases: ["map"]}
    }

    player = %{player_env_family(%{gender: "男性"}, nil) | inventory: [%{item: map_item}]}

    MoveEvent.notice(build_conn(npc_of("gaochang:waer", "瓦耳拉齐")), notice_event(player))

    assert_receive {:room_message, text}
    assert text =~ "给我受死"
    assert_receive %Event{topic: "combat/start"}
  end

  test "瓦耳拉齐：身上没 map → 只嗤笑，不开战" do
    MoveEvent.notice(
      build_conn(npc_of("gaochang:waer", "瓦耳拉齐")),
      notice_event(player_env_family(%{gender: "男性"}, nil))
    )

    assert_receive {:room_message, text}
    assert text =~ "嗤笑"
    refute_receive %Event{topic: "combat/start"}, 100
  end

  test "苗人巫士：见人就开战，无台词" do
    MoveEvent.notice(
      build_conn(npc_of("mingjiao:miaozuwushi", "巫士")),
      notice_event(player_env_family(%{gender: "男性"}, nil))
    )

    assert_receive %Event{topic: "combat/start"}
    refute_receive {:room_message, _}, 100
  end

  test "蒙面人：不打招呼（杀戮由房间快照驱动）" do
    assert :skip =
             Kantele.World.NpcGreeting.greet(
               npc_of("wudang:mengmian", "蒙面人"),
               player_env_family(%{gender: "男性"}, nil)
             )
  end

  # ---- 属性分支 / 入房抓人 ----

  defp player_per(per) do
    base = player_env_family(%{gender: "男性"}, nil)
    %{base | attributes: %{per: per}}
  end

  test "颜如玉：per<20 招揽美容生意" do
    MoveEvent.notice(build_conn(npc_of("city:yanruyu", "颜如玉")), notice_event(player_per(15)))

    assert_receive {:room_message, text}
    assert text =~ "美容养颜"
  end

  test "颜如玉：per>=20 不问候" do
    MoveEvent.notice(build_conn(npc_of("city:yanruyu", "颜如玉")), notice_event(player_per(25)))
    refute_receive {:room_message, _}, 100
  end

  test "颜如玉：未记录 per 的玩家不问候（缺省按 20）" do
    MoveEvent.notice(
      build_conn(npc_of("city:yanruyu", "颜如玉")),
      notice_event(player_env_family(%{gender: "男性"}, nil))
    )

    refute_receive {:room_message, _}, 100
  end

  defp wanted_player do
    base = player_env_family(%{gender: "男性"}, %{name: "天地会"})
    %{base | meta: %{base.meta | stats: %{base.meta.stats | combat_exp: 200_000}}}
  end

  test "石松：天地会且实战经验>15万 → 喝道并开战" do
    MoveEvent.notice(build_conn(npc_of("city:shisong", "石松")), notice_event(wanted_player()))

    assert_receive {:room_message, text}
    assert text =~ "天地会反贼"
    assert_receive %Event{topic: "combat/start"}
  end

  test "石松：普通玩家 → 不理会" do
    MoveEvent.notice(
      build_conn(npc_of("city:shisong", "石松")),
      notice_event(player_env_family(%{gender: "男性"}, %{name: "武当派"}))
    )

    refute_receive {:room_message, _}, 100
    refute_receive %Event{topic: "combat/start"}, 50
  end
end
