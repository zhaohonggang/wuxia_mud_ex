defmodule Kantele.World.UltraAndSpecialNpcTest do
  @moduledoc """
  #1049/#1050/#1051 定向测试：四位大宗师、上官银票、李白字段补齐。

  数据侧全部读真实 `data/world/*.ucl`（Loader.load），逻辑侧直接调
  `Kantele.NPC.Ultra` 的纯函数，避免起房间/进程。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.{Combat, PlayerMeta, Stats, Vitals}
  alias Kantele.Character.UltraEvent
  alias Kantele.NPC.Ultra
  alias Kantele.World.Loader
  alias Kantele.World.NpcInit
  alias Kantele.Npc.EngageRule

  setup_all do
    %{world: Loader.load()}
  end

  defp npc(world, name) do
    Enum.find(world.characters, &(&1.name == name)) ||
      Enum.find_value(world.zones, fn zone ->
        Enum.find(Map.values(zone.characters || %{}), &(&1.name == name))
      end)
  end

  # 按 zone + 块 key 精确定位，避开 world.characters 里同名的老 NPC（哈希 id）。
  defp zone_npc(world, zone_id, key) do
    zone = Enum.find(world.zones, &(&1.id == zone_id))
    Map.get(zone.characters || %{}, String.to_atom(key))
  end

  defp ultra_npc(name) do
    world = Loader.load()

    case name do
      "独孤求败" -> zone_npc(world, "huashan", "ultra_dugu")
      "黄裳" -> zone_npc(world, "dali", "ultra_huang")
      "霍山" -> zone_npc(world, "mingjiao", "ultra_huoshan")
      "葵花太监" -> zone_npc(world, "beijing", "ultra_kuihua")
    end
  end

  defp player(overrides \\ %{}) do
    stats =
      %Stats{
        combat_exp: 300_000,
        str: 40,
        int: 45,
        con: 40,
        dex: 40,
        skills: %{"force" => 300, "sword" => 300, "dodge" => 300, "martial-cognize" => 100},
        mapped: %{"force" => "jiuyang-shengong"},
        performs: MapSet.new()
      }
      |> Map.merge(Map.get(overrides, :stats, %{}))

    env = Map.merge(%{}, Map.get(overrides, :env, %{}))
    temp = Map.merge(%{}, Map.get(overrides, :temp, %{}))

    meta = %PlayerMeta{
      stats: stats,
      vitals: %Vitals{
        qi: 10_000,
        max_qi: 10_000,
        jing: 10_000,
        max_jing: 10_000,
        neili: 5_000,
        max_neili: 5_000
      },
      combat: %Combat{},
      env: env,
      temp: temp
    }

    %{id: "test:player", name: "测试者", meta: meta, pid: nil}
  end

  # ---- 数据：四位大宗师 ----

  test "四位大宗师 NPC 块落在各自 startroom，字段与 LPC 一致", ctx do
    for {name, zone, key, id, category} <- [
          {"独孤求败", "huashan", "ultra_dugu", "huashan:ultra_dugu", "weapon"},
          {"黄裳", "dali", "ultra_huang", "dali:ultra_huang", "unarmed"},
          {"霍山", "mingjiao", "ultra_huoshan", "mingjiao:ultra_huoshan", "force"},
          {"葵花太监", "beijing", "ultra_kuihua", "beijing:ultra_kuihua", "dodge"}
        ] do
      ob = zone_npc(ctx.world, zone, key)
      assert ob != nil, "#{name} NPC 块缺失"
      assert ob.id == id
      assert ob.meta.stats.combat_exp == 50_000_000
      assert ob.meta.vitals.max_neili == 30_000
      assert ob.meta.combat.jiali == 100
      assert ob.meta.ultra.category == category
      assert ob.meta.ask_handler == "Kantele.NPC.Ultra"
      assert Map.get(ob.meta.env, "opinion/ultra") == 1
      assert Map.get(ob.meta, :teach) == nil
      assert Map.get(ob.meta, :apprentice) == nil
      assert is_binary(ob.meta.ultra.msgs["vanish"])
      assert is_binary(ob.meta.ultra.msgs["vanish_chat"])
    end

    room_names = fn zone_id, room_key ->
      zone = Enum.find(ctx.world.zones, &(&1.id == zone_id))
      room = Enum.find(zone.rooms, &(&1.key == room_key))
      Enum.map(room.characters, & &1.name)
    end

    assert "独孤求败" in room_names.("huashan", "shandong")
    assert "黄裳" in room_names.("dali", "lushui")
    assert "霍山" in room_names.("mingjiao", "xuantianshi")
    assert "葵花太监" in room_names.("beijing", "shanlu3")
  end

  test "大宗师 quest 物品与 accept 规则齐备" do
    for item_id <- ["clone_lib:dugubook", "clone_lib:zhenjing1", "clone_lib:zhenjing2"] do
      assert Enum.any?(Loader.load().items, &(&1.id == item_id)), "#{item_id} 缺失"
    end

    world = Loader.load()
    dugu = zone_npc(world, "huashan", "ultra_dugu")
    huang = zone_npc(world, "dali", "ultra_huang")

    assert [%{kind: "ultra", action: "dugubook"}] = dugu.meta.accept
    assert Enum.map(huang.meta.accept, & &1.action) == ["zhenjing1", "zhenjing2"]
  end

  # ---- 数据：#1050 / #1051 ----

  test "李白块补齐 6 字段（门派/残本标志/容貌/内力/加力/神酒）" do
    libai = npc(Loader.load(), "李白")
    assert libai.meta.family == "侠客盟"
    assert Map.get(libai.meta.env, "dugu-jiujian/nothing") == 1
    assert libai.meta.stats.per == 50
    assert libai.meta.vitals.neili == 12_000
    assert libai.meta.combat.jiali == 250
    assert libai.meta.handing == "death:shenjiu"
  end

  test "上官银票块补齐（金钱帮/score/idle-force/加力）" do
    cash = npc(Loader.load(), "上官银票")
    assert cash != nil
    assert cash.meta.family == "金钱帮"
    assert cash.meta.stats.score == 70_000
    assert cash.meta.stats.skills["idle-force"] == 500
    assert cash.meta.combat.jiali == 160
    assert cash.meta.vitals.neili == 7_000
  end

  # ---- 数据：#1032 遗留的 combat.jiali / combat.neili 回填 ----

  test "商剑鸣 jiali=180 / neili=6000 已回填且被 loader 读取" do
    shang = zone_npc(Loader.load(), "clone_lib", "shang_ming")
    assert shang != nil
    assert shang.name == "商剑鸣"
    assert shang.meta.combat.jiali == 180
    assert shang.meta.vitals.neili == 6_000
    assert shang.meta.vitals.max_neili == 6_000
  end

  # ---- #1055：大宗师 init()（ultrap 反应 + 清 want_opinion） ----

  @tag :npc_init
  test "四位大宗师 init 文案与 LPC init() 逐字一致" do
    for {zone, key, text} <- [
          {"huashan", "ultra_dugu", "{npc}微微一笑，对{name}点了点头。"},
          {"dali", "ultra_huang", "{npc}微微一笑，对{name}点了点头。"},
          {"mingjiao", "ultra_huoshan", "{npc}眉头一皱，哼了一声。"},
          {"beijing", "ultra_kuihua", "{npc}扫了{name}一眼，冷笑一声。"}
        ] do
      ob = zone_npc(Loader.load(), zone, key)
      assert ob.meta.ultra.msgs["init"] == text, "#{zone}:#{key} init 文案不符"
    end
  end

  @tag :npc_init
  test "init()：ultrap 玩家显反应，非 ultrap 只清意图；普通 NPC 完全不触发" do
    master = %{player(%{env: %{"opinion/ultra" => 1}}) | pid: self()}
    plain = %{player() | pid: self()}

    for {zone, key, text} <- [
          {"huashan", "ultra_dugu", "{npc}微微一笑，对{name}点了点头。"},
          {"dali", "ultra_huang", "{npc}微微一笑，对{name}点了点头。"},
          {"mingjiao", "ultra_huoshan", "{npc}眉头一皱，哼了一声。"},
          {"beijing", "ultra_kuihua", "{npc}扫了{name}一眼，冷笑一声。"}
        ] do
      assert {:vision, ^text} = NpcInit.init(zone_npc(Loader.load(), zone, key), master)
      assert_receive %Kalevala.Event{topic: "ultra/init", data: %{clear_want_opinion: true}}
    end

    dugu = zone_npc(Loader.load(), "huashan", "ultra_dugu")
    assert :skip = NpcInit.init(dugu, plain)
    assert_receive %Kalevala.Event{topic: "ultra/init", data: %{clear_want_opinion: true}}

    assert :skip = NpcInit.init(zone_npc(Loader.load(), "clone_lib", "shang_ming"), master)
    refute_receive %Kalevala.Event{}
  end

  @tag :npc_init
  test "ultra/init 回执清掉全部 want_opinion/<key>，保留其他 temp" do
    p =
      player(%{
        temp: %{
          "want_opinion/dugu" => 2,
          "want_opinion/shenni" => 1,
          "opinion" => "x"
        }
      })

    conn = %Kalevala.Character.Conn{character: p}
    conn = UltraEvent.clear_intent(conn, %{data: %{clear_want_opinion: true}})
    # put_character/2 stages into private.update_character; engine flushes it later.
    updated = conn.private.update_character
    temp = updated.meta.temp

    refute Map.has_key?(temp, "want_opinion/dugu")
    refute Map.has_key?(temp, "want_opinion/shenni")
    assert temp["opinion"] == "x"

    # 非本事件原样返回 conn（router 兜底分支）
    assert UltraEvent.clear_intent(conn, %{data: %{}}) == conn
  end

  # ---- 逻辑：ask 门控 ----

  test "评价 exp 门槛与已宗师拒绝" do
    world = Loader.load()
    dugu = zone_npc(world, "huashan", "ultra_dugu")
    low = player(%{stats: %{combat_exp: 199_999}})

    assert {:error, text} = Ultra.check(low, dugu, "评价")
    assert text =~ "这点武功还谈什么评价"

    master = player(%{env: %{"opinion/weapon" => "宗师"}})
    assert {:error, text} = Ultra.check(master, dugu, "评价")
    assert text =~ "宗师了"
  end

  test "静态 inquiry 未被 ask_handler 吞掉" do
    dugu = ultra_npc("独孤求败")
    assert {:error, text} = Ultra.check(player(), dugu, "独孤九剑")
    assert text =~ "天下武功的变化"
  end

  test "重复 ask 累加 want_opinion，第三次起拒绝" do
    dugu = ultra_npc("独孤求败")
    p0 = player()

    assert {:ok, text, p1} = Ultra.execute(p0, dugu, "评价")
    assert text =~ "用兵器攻我一招"
    assert PlayerMeta.get_temp(p1.meta, "want_opinion/dugu") == 1

    p2 = elem(Ultra.execute(p1, dugu, "评价"), 2)
    p3 = elem(Ultra.execute(p2, dugu, "评价"), 2)
    assert PlayerMeta.get_temp(p3.meta, "want_opinion/dugu") == 3
    assert {:error, text} = Ultra.check(p3, dugu, "评价")
    assert text =~ "闭上你的嘴"
  end

  # ---- 逻辑：fight 门控 / 评级 ----

  test "无意图 fight 被拒；有意向则试招并拒绝真战斗" do
    dugu = ultra_npc("独孤求败")
    assert {:deny, msg} = Ultra.engage_decide(dugu, player(), "fight")
    assert msg =~ "平白无故动什么手"

    p = player(%{temp: %{"want_opinion/dugu" => 1}})
    p = put_in(p.meta.combat.equipped, %{weapon: %{name: "木剑"}})
    assert {:deny, msg} = Ultra.engage_decide(dugu, p, "fight")
    assert msg =~ "不能心急"
  end

  test "霍山内力不足 3000 拒评；达宗师后放行切磋" do
    huoshan = ultra_npc("霍山")
    weak = player(%{temp: %{"want_opinion/shenni" => 1}, stats: %{skills: %{"force" => 300}}})
    weak = put_in(weak.meta.vitals.neili, 2_999)
    assert {:deny, msg} = Ultra.engage_decide(huoshan, weak, "fight")
    assert msg =~ "内力不足"

    master = player(%{env: %{"opinion/force" => "宗师"}})
    assert :allow = Ultra.engage_decide(huoshan, master, "fight")
  end

  test "check_opinion 按 opinions_rank 升档并持久化" do
    huoshan = ultra_npc("霍山")
    cfg = huoshan.meta.ultra
    # force 300/2 + jiuyang-shengong 200 + 20(max_neili>4000) = 370 → 已有大成(360)
    p = player(%{stats: %{skills: %{"force" => 300, "jiuyang-shengong" => 200}}, env: %{}})
    {p, text} = Ultra.check_opinion(p, huoshan, cfg)
    assert Ultra.opinion_of(p, "force") == "已有大成"
    assert text =~ "已有大成"
  end

  test "四类全宗师 → opinion/ultra=1 + rumor" do
    huoshan = ultra_npc("霍山")

    p =
      player(%{
        env: %{
          "opinion/unarmed" => "宗师",
          "opinion/weapon" => "宗师",
          "opinion/force" => "已有大成",
          "opinion/dodge" => "宗师"
        },
        stats: %{skills: %{"force" => 600, "jiuyang-shengong" => 400}}
      })

    {p, _text} = Ultra.check_opinion(p, huoshan, huoshan.meta.ultra)
    assert Ultra.opinion_of(p, "force") == "宗师"
    assert p.meta.env["opinion/ultra"] == 1
  end

  test "EngageRule 只在配置了 handler 的 NPC 上走动态判定" do
    dugu = ultra_npc("独孤求败")
    assert {:deny, _} = EngageRule.decide(dugu.meta, "fight", dugu.name, dugu, player())
    assert :allow = EngageRule.decide(%{attitude: "friendly"}, "fight", "某人", dugu, player())
  end
end
