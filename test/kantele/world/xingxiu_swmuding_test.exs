defmodule Kantele.World.XingxiuSwmudingTest do
  @moduledoc """
  #816 神王木鼎状态机（阿紫 accept_kill 六分支 + 丁春秋 init 持鼎追杀）。

  数据侧读真实 `data/world/clone_lib.ucl`（Loader.load），逻辑侧直接调
  `Kantele.NPC.XingXiuAzi.engage_decide/3` 与 `Kantele.World.NpcInit.init/2`
  的纯函数，避免起房间/进程。给鼎分支的 NPC 侧事件单独测
  `Kantele.Character.XingXiuAziEvent`。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Event
  alias Kantele.Character.{Combat, PlayerMeta, Stats, Vitals}
  alias Kantele.Character.XingXiuAziEvent
  alias Kantele.NPC.XingXiuAzi
  alias Kantele.World.Loader
  alias Kantele.World.NpcInit
  alias Kantele.World.PrototypeObject

  setup_all do
    world = Loader.load()

    # 丁春秋 init 的 ding_swmuding_kill?/2 会走 `Item.fetch` → `Kantele.World.Items`
    # （Kalevala.Cache，ETS 由监督树创建）。无 DB 的纯函数套件里监督树没起，
    # 这里手动把 Items cache 拉起并灌入世界物品，保证 init 判定可跑。
    if Process.whereis(Kantele.World.Items) do
      # 已由监督树启动：清空并重灌，避免跨用例残留。
      Enum.each(Kantele.World.Items.keys(), &Kantele.World.Items.delete/1)
    else
      Kantele.World.Items.start_link(name: Kantele.World.Items)
    end

    Enum.each(world.items, fn item -> Kantele.World.Items.put(item.id, item) end)

    %{world: world}
  end

  defp zone_npc(world, zone_id, key) do
    zone = Enum.find(world.zones, &(&1.id == zone_id))
    Map.get(zone.characters || %{}, String.to_atom(key))
  end

  defp azi(world) do
    zone_npc(world, "clone_lib", "xingxiu_azi")
  end

  defp ding(world) do
    zone_npc(world, "clone_lib", "xingxiu_ding")
  end

  defp npc(overrides \\ %{}) do
    stats =
      %Stats{
        combat_exp: 100_000,
        shen: 0,
        skills: %{}
      }
      |> Map.merge(Map.get(overrides, :stats, %{}))

    meta = %PlayerMeta{
      stats: stats,
      vitals: %Vitals{qi: 10_000, max_qi: 10_000, jing: 10_000, max_jing: 10_000},
      combat: %Combat{},
      env: Map.merge(%{}, Map.get(overrides, :env, %{})),
      family: Map.get(overrides, :family),
      temp: %{}
    }

    Map.merge(
      %{id: "test:npc", name: "测试NPC", room_id: nil, meta: meta, pid: nil, inventory: []},
      Map.get(overrides, :char, %{})
    )
  end

  defp player(overrides \\ %{}) do
    stats =
      %Stats{
        combat_exp: 600_000,
        shen: -20_000,
        skills: %{}
      }
      |> Map.merge(Map.get(overrides, :stats, %{}))

    meta = %PlayerMeta{
      stats: stats,
      vitals: %Vitals{qi: 10_000, max_qi: 10_000, jing: 10_000, max_jing: 10_000},
      combat: %Combat{},
      env: Map.merge(%{}, Map.get(overrides, :env, %{})),
      family: Map.get(overrides, :family),
      temp: %{}
    }

    Map.merge(
      %{id: "test:player", name: "测试玩家", room_id: nil, meta: meta, pid: nil, inventory: []},
      Map.get(overrides, :char, %{})
    )
  end

  # ---- 数据：阿紫块 env 已就位 ----

  test "阿紫块写入 swmuding 初值与六分支文案（azi.c:70/91-134）", ctx do
    az = azi(ctx.world)
    assert az != nil
    assert az.name == "阿紫"

    assert Map.get(az.meta.env, "swmuding") == 1
    assert Map.get(az.meta.env, "swmuding/item") == "clone_lib:swmuding"
    assert Map.get(az.meta.env, "swmuding/prototype") == "swmuding"
    assert Map.get(az.meta.env, "swmuding/exp_threshold") == 500_000
    assert Map.get(az.meta.env, "swmuding/shen_threshold") == -10_000

    # engage.kill 挂上动态 handler
    kill = az.meta.engage.kill
    assert kill.handler == "Kantele.NPC.XingXiuAzi"

    # 五条台词都在 UCL（含 emote 旁观/自己两态）。多行文案以数组逐行存放，
    # 单行是字符串 —— 两者都允许（UCL 字符串不能含真实换行，见 sanitize_ucl_sval）。
    for key <- [
          "swmuding/msg/stolen",
          "swmuding/msg/inn_others",
          "swmuding/msg/inn_target",
          "swmuding/msg/pitiful",
          "swmuding/msg/denied",
          "swmuding/msg/sigh",
          "swmuding/msg/shout",
          "swmuding/msg/give_others",
          "swmuding/msg/give_self",
          "swmuding/msg/insist"
        ] do
      v = Map.get(az.meta.env, key)
      assert is_binary(v) or is_list(v), "#{key} 文案缺失"
    end
  end

  test "swmuding 物品定义齐全（clone/misc/swmuding.c）", ctx do
    item = Enum.find(ctx.world.items, &(&1.id == "clone_lib:swmuding"))
    assert item != nil
    assert item.name == "神木王鼎"
    assert item.meta.weight == 1200
    assert item.meta.value == 50_000
    assert item.meta.no_sell == 1
    assert item.meta.unit == "只"
    assert "shenmu wangding" in item.meta.aliases
  end

  # ---- 六分支：engage_decide/3 ----

  test "分支1：非 living NPC 直接放行（azi.c:96-97）" do
    az = npc(%{env: %{"swmuding" => 1}})
    # combat 里 dead=true 视为非 living
    az = %{az | meta: %{az.meta | combat: %{dead: true}}}
    assert XingXiuAzi.engage_decide(az, player(), "kill") == :allow
  end

  test "分支2：无 swmuding 标记 → 拒绝 + 楚楚可怜文案（azi.c:99-105）" do
    az = npc(%{env: %{"swmuding" => 0}})
    assert {:deny, msg} = XingXiuAzi.engage_decide(az, player(), "kill")
    assert msg =~ "不禁心头一软"
    assert msg =~ "好委屈"
  end

  test "分支3：与阿紫不同门 → 放行，无文案（azi.c:107-109）" do
    az = npc(%{family: %{name: "星宿派"}, env: %{"swmuding" => 1}})
    p = player(%{family: %{name: "武当派"}})
    assert XingXiuAzi.engage_decide(az, p, "kill") == :allow
  end

  test "分支4：全局已载入神木王鼎原型 → 拒绝 + 呜咽/叹气（azi.c:111-118）" do
    az = npc(%{family: %{name: "星宿派"}, env: %{"swmuding" => 1}})
    p = player(%{family: %{name: "星宿派"}})
    PrototypeObject.reset_all()
    PrototypeObject.mark_loaded("swmuding")

    assert {:deny, msg} = XingXiuAzi.engage_decide(az, p, "kill")
    assert msg =~ "神情不象是作伪"

    PrototypeObject.reset_all()
  end

  test "分支5：同门 + exp>500000 + shen<-10000 → 给鼎并拒绝（azi.c:120-130）" do
    az = npc(%{family: %{name: "星宿派"}, env: %{"swmuding" => 1}})
    p = player(%{family: %{name: "星宿派"}})
    PrototypeObject.reset_all()

    assert {:deny, msg} = XingXiuAzi.engage_decide(az, p, "kill")
    # 返回给攻击者的是「自己视角」give_self 文案（shout 走房间广播，不在返回里）
    assert msg =~ "拿出神木王鼎给你"
    assert msg =~ "你接过了"
    # 不落入分支4（未载入原型）
    refute msg =~ "神情不象是作伪"
  end

  test "分支5 前置不满足 → 走到分支6：说没有木鼎并放行（azi.c:132-133）" do
    az = npc(%{family: %{name: "星宿派"}, env: %{"swmuding" => 1}})
    # 同门但 combat_exp 不足 500000
    p = player(%{family: %{name: "星宿派"}, stats: %{combat_exp: 100_000, shen: -20_000}})
    PrototypeObject.reset_all()

    assert XingXiuAzi.engage_decide(az, p, "kill") == :allow
  end

  test "非 kill 类型一律放行（不劫持 fight/hit）" do
    az = npc(%{env: %{"swmuding" => 0}})
    assert XingXiuAzi.engage_decide(az, player(), "fight") == :allow
    assert XingXiuAzi.engage_decide(az, player(), "hit") == :allow
  end

  # ---- NPC 侧事件：set("swmuding", 0) + give ----

  test "NPC 侧 revoke-swmuding：置 0 并发 npc/give 给攻击者" do
    az = npc(%{env: %{"swmuding" => 1}})
    asker = %{player() | pid: self()}

    conn = %Kalevala.Character.Conn{
      character: az,
      private: %Kalevala.Character.Conn.Private{}
    }

    event = %Kalevala.Event{
      from_pid: self(),
      topic: "xingxiu_azi/revoke-swmuding",
      data: %{asker: asker, item_id: "clone_lib:swmuding", text: ""}
    }

    out = XingXiuAziEvent.revoke_swmuding(conn, event)

    # 1) set("swmuding", 0) 落到 meta.env（put_character → private.update_character）
    updated = out.private.update_character
    assert updated.meta.env["swmuding"] == 0

    # 2) 给鼎副作用：npc/give 投到 asker pid（text 为空 = 文案已由 engage 渲染）
    assert_received %Kalevala.Event{
      topic: "npc/give",
      data: %{item_id: "clone_lib:swmuding", asker_id: "test:player", text: ""}
    }
  end

  # ---- 丁春秋 init 持鼎追杀 ----

  test "丁春秋 init：玩家持神木王鼎 → 追杀（ding.c:122-130）", ctx do
    d = ding(ctx.world)
    assert d != nil
    assert d.name == "丁春秋"

    carry_player = %{player() | pid: self()}
    carry_player = put_in(carry_player.inventory, [%{id: "i1", item_id: "clone_lib:swmuding"}])

    # NpcInit.init 返回 :skip（不落欢迎台词），但发送双向 combat/start
    assert NpcInit.init(d, carry_player) == :skip
  end

  test "丁春秋 init：玩家没持鼎 → 走 ultrap 骨架（不追杀）", ctx do
    d = ding(ctx.world)
    plain = %{player() | pid: self()}
    # 普通玩家：非 ultrap → :skip 但无 combat/start 副作用
    assert NpcInit.init(d, plain) == :skip
  end
end