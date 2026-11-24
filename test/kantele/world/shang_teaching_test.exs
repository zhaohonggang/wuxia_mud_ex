defmodule Kantele.World.ShangTeachingTest do
  @moduledoc """
  #1031 商家堡（shang）教学门控定向测试。

  数据来源：LPC `kungfu/class/shang/{shang.h,ming.c,tai.c,zhen.c}` 与
  `d/shaolin/{shang_dating.c,shang_men.c}`。重点锁定：

    1. `shang.h::permit_recruit` 无条件 `return 0` → 商剑鸣 / 商老太 `deny_all = true`
       + 逐字 `deny_msg`（不可达的改名/经验/杀气/内功门全部关闭）；
       商宝震 LPC 不调 permit_recruit，自己 `command("shake")` + say 回绝 → 也须 deny_all；
    2. 商剑鸣 / 商老太 / 商宝震的战斗闲聊载荷（`chat_chance_combat` + 逐条 `chat_msg_combat`）；
    3. 商老太 `no_teach` 两态：`bagua-dao` 逐字串拒 / `wai-bagua` 条件解锁
       （mark → learned；`combat_exp > 100000` → learned + 落 mark；否则 → locked）；
    4. 商宝震 `meta.guarder`（family + 两句拒绝台词）与 `coagents`（商剑鸣）；
    5. `shaolin:shang_dating` **只有 1 个商剑鸣**（薄副本退役后不得回归）；
    6. `shaolin:shang_men` 守卫方向只守 `north`（`south` 直通官道放行）；
    7. 商剑鸣 `combat.apply`（damage / unarmed_damage / armor）。
  """

  use ExUnit.Case, async: true

  alias Kantele.SectMaster
  alias Kantele.World.Loader

  setup_all do
    %{world: Loader.load()}
  end

  # loader 给 NPC 分配的运行时 id 是短 uuid（`zone_id` 另存在 meta.zone_id），
  # 不能按 "clone_lib:shang_ming" 这类静态 id 找；统一按别名查（与 lingxiao 测试同法）。
  defp npc(world, alias_key) do
    Enum.find(world.characters, fn c ->
      Enum.any?(c.meta.aliases || [], &(&1 == alias_key))
    end)
  end

  # ---------- 1. 收徒门控（shang.h permit_recruit 恒 0）----------

  describe "apprentice 门控 —— 商家堡不对外收徒" do
    @deny "我商家堡武功脱胎于八卦门，不对外收徒。"

    test "商剑鸣 deny_all + 逐字 deny_msg", %{world: world} do
      app = npc(world, "shang jianming").meta.apprentice

      assert app
      assert app.deny_all == true
      assert app.deny_msg == @deny
      refute app.permit_recruit == true
    end

    test "商老太 deny_all + 逐字 deny_msg", %{world: world} do
      app = npc(world, "shang laotai").meta.apprentice

      assert app
      assert app.deny_all == true
      assert app.deny_msg == @deny
      refute app.permit_recruit == true
    end

    test "商宝震 deny_all + 逐字 deny_msg（LPC 自己回绝，不调 permit_recruit）", %{world: world} do
      app = npc(world, "shang baozhen").meta.apprentice

      assert app
      assert app.deny_all == true

      assert app.deny_msg ==
               "你去找我爹爹或是娘亲好了，我自己的武功都没练什么呢。"

      refute app.permit_recruit == true
    end

    test "三位师父 teach.family 仍是商家堡（否认门只影响拜师，不影响授艺）", %{world: world} do
      for id <- ["shang jianming", "shang laotai"] do
        assert npc(world, id).meta.teach.family == "商家堡", "#{id} teach.family"
      end

      # 商宝震 LPC 无 teach（只继承 F_GUARDER）→ 没有 teach 段是对的
      refute npc(world, "shang baozhen").meta.teach
    end
  end

  # ---------- 2. 战斗闲聊载荷 ----------

  describe "chat_msg_combat 载荷逐字保留" do
    @payloads %{
      "shang jianming" => [
        "blade.mang",
        "blade.sha",
        "strike.ding",
        "cuff.gua",
        "parry.zhen",
        "throwing.huan",
        "recover",
        "powerup"
      ],
      "shang laotai" => [
        "blade.mang",
        "strike.ding",
        "cuff.gua",
        "parry.zhen",
        "throwing.huan",
        "recover"
      ],
      "shang baozhen" => [
        "blade.mang",
        "strike.ding",
        "cuff.gua",
        "parry.zhen",
        "throwing.huan",
        "recover"
      ]
    }

    test "8 / 6 / 6 条与 LPC 顺序一致", %{world: world} do
      for {id, payload} <- @payloads do
        assert npc(world, id).meta.chat_msg_combat == payload, "#{id} chat_msg_combat"
      end
    end

    test "三人 chat_chance_combat 都是 120", %{world: world} do
      for {id, _payload} <- @payloads do
        assert npc(world, id).meta.chat_chance_combat == 120, "#{id} chat_chance_combat"
      end
    end
  end

  # ---------- 3. 商老太 no_teach 两态 ----------

  describe "商老太 no_teach（LPC tai.c:77-80）" do
    # teachable?/3 的 student 形状：`%{meta: %{family: map, stats: map, marks: map}}`
    # （sect_master.ex:2185-2229 的 meta_of / student_stats_of / student_marks）。
    # 注意：调用点必须显式传 map（`student(%{stats: ...})`），关键字 list 不是 map。
    defp student(overrides) do
      stats = Map.get(overrides, :stats, %{})

      stats =
        stats
        |> Map.put_new(:combat_exp, 0)
        |> Map.put_new(:skills, %{})

      %{
        meta: %{
          family: Map.get(overrides, :family, %{name: "商家堡", master_name: "商剑鸣"}),
          stats: stats,
          marks: Map.get(overrides, :marks, %{})
        }
      }
    end

    test "bagua-dao 是逐字串拒（八卦刀需由我夫君亲自传授）", %{world: world} do
      tai = npc(world, "shang laotai")

      # no_teach_reason/2 经 ensure_lf 补行尾换行（host 输出契约）
      assert {:error, "八卦刀需由我夫君亲自传授。\n"} = SectMaster.teachable?(tai, student(%{}), "bagua-dao")
    end

    test "wai-bagua：已持 mark → 放行（learned 台词）", %{world: world} do
      tai = npc(world, "shang laotai")

      marked = student(%{marks: %{"can_learn/shanglaotai/wai-bagua" => true}})

      # {:unlock, learned, mark}；已持 mark 时 mark 回传 nil（无需再落盘）
      assert {:unlock, "看来你武功已有了一定火候，我就替夫君传你外八卦神功。", nil} =
               SectMaster.teachable?(tai, marked, "wai-bagua")
    end

    test "wai-bagua：combat_exp > 100000 → 放行 + 落 mark", %{world: world} do
      tai = npc(world, "shang laotai")

      # 100000 是下界（LPC `combat_exp > 100000` 严格大于）
      low = student(%{stats: %{combat_exp: 100_000}})

      assert {:error, "你此时功力太浅，还是先学一些入门功夫吧。"} = SectMaster.teachable?(tai, low, "wai-bagua")

      high = student(%{stats: %{combat_exp: 100_001}})

      # 未持 mark 但 combat_exp > 100000 → 本次解锁，回传 mark 供 host 落盘
      assert {:unlock, "看来你武功已有了一定火候，我就替夫君传你外八卦神功。", "can_learn/shanglaotai/wai-bagua"} =
               SectMaster.teachable?(tai, high, "wai-bagua")
    end

    test "wai-bagua：combat_exp 不足且未持 mark → 拒绝", %{world: world} do
      tai = npc(world, "shang laotai")

      assert {:error, "你此时功力太浅，还是先学一些入门功夫吧。"} =
               SectMaster.teachable?(tai, student(%{stats: %{combat_exp: 99_999}}), "wai-bagua")
    end
  end

  # ---------- 4. 商宝震 guarder / coagents ----------

  describe "商宝震 meta.guarder / coagents" do
    test "meta.guarder family=商家堡 + 两句逐字拒绝台词", %{world: world} do
      guarder = npc(world, "shang baozhen").meta.guarder

      assert guarder
      assert guarder.family == "商家堡"

      assert guarder.msgs.refuse_other ==
               "{npc}对{name}冷喝道：你给我站住！我们商家堡岂是由得外人随便走动地方？"

      assert guarder.msgs.refuse_carry ==
               "{npc}对{name}喝道：你背上背的是什么人？给我放下来！"

      # $N/$n 已被 parse_guarder → normalize_guarder_msg 归一为 {npc}/{name}
      refute Map.values(guarder.msgs) |> Enum.any?(&String.contains?(&1, "$N"))
      refute Map.values(guarder.msgs) |> Enum.any?(&String.contains?(&1, "$n"))
    end

    test "coagents 指向商剑鸣 / shaolin:shang_dating", %{world: world} do
      coagents = npc(world, "shang baozhen").meta.coagents

      assert is_list(coagents)
      assert length(coagents) == 1

      [co] = coagents
      assert co["id"] == "shang jianming"
      assert co["startroom"] == "shaolin:shang_dating"
    end
  end

  # ---------- 5. 大厅去重 ----------

  describe "shaolin:shang_dating 只有 1 个商剑鸣" do
    test "薄副本 characters \"shang_jianming\" 已退役", %{world: world} do
      refute npc(world, "shaolin:shang_jianming"),
             "shaolin.ucl characters \"shang_jianming\" 应已退役（权威定义在 clone_lib.ucl shang_ming）"

      assert npc(world, "shang jianming")
    end

    test "大厅 occupants 里名字为「商剑鸣」的 NPC 恰好 1 个", %{world: world} do
      shang =
        world.characters
        |> Enum.filter(&(&1.room_id == "shaolin:shang_dating"))
        |> Enum.filter(&(&1.name == "商剑鸣"))

      assert length(shang) == 1, "商家堡大厅应有且仅应有 1 个商剑鸣，实际 #{length(shang)}"
      assert hd(shang).meta.zone_id == "clone_lib"
      assert "shang_ming" in (hd(shang).meta.aliases || [])
    end
  end

  # ---------- 6. 商家堡大门守卫方向 ----------

  describe "shaolin:shang_men 守卫方向（LPC shang_men.c::valid_leave）" do
    alias Kalevala.Event
    alias Kalevala.Event.Movement
    alias Kalevala.World.Room.Context

    @handler Kalevala.World.Room.Callbacks.Kantele.World.Room

    setup do
      world = Loader.load()

      Enum.each(world.zones, fn
        %{id: _} = zone -> Kantele.World.ZoneCache.cache(zone)
        _ -> :skip
      end)

      room = Enum.find(world.rooms, &(&1.id == "shaolin:shang_men"))
      occupants = Enum.filter(world.characters, &(&1.room_id == "shaolin:shang_men"))

      %{room: room, occupants: occupants}
    end

    defp room_exit(room, dir), do: Enum.find(room.exits, &(&1.exit_name == dir))

    defp mover(family_name) do
      family = if family_name, do: %{name: family_name}, else: nil
      %{pid: self(), name: "测试玩家", meta: %{family: family}}
    end

    defp move(room, characters, player, dir) do
      exit = room_exit(room, dir)
      assert exit, "shang_men 没有方向 #{dir}"

      event = %Event{
        topic: Movement.Request,
        from_pid: self(),
        data: %Movement.Request{character: player, exit_name: dir}
      }

      context = %Context{
        data: room,
        characters: characters,
        item_instances: [],
        assigns: %{},
        events: [],
        output: []
      }

      @handler.movement_request(room, context, event, exit)
    end

    test "behavior_config 只守 north", %{room: room} do
      assert room.behavior == "guarded_exit"
      assert room.behavior_config.guard_directions == ["north"]
    end

    test "商宝震在 rooms 的 occupants 里（守卫本身存在）", %{occupants: occupants} do
      names = Enum.map(occupants, & &1.name)
      assert "商宝震" in names
    end

    test "无门派玩家 north 被商宝震拦下", %{room: room, occupants: occupants} do
      assert {:abort, _event, {:guarder_denied, msg}} = move(room, occupants, mover(nil), "north")

      assert msg =~ "我们商家堡岂是由得外人随便走动地方？",
             "north 的拒绝语应出自商宝震的 refuse_other，实际：#{msg}"
    end

    test "south 直通官道放行（不被守卫拦）", %{room: room, occupants: occupants} do
      refute match?(
               {:abort, _event, {:guarder_denied, _msg}},
               move(room, occupants, mover(nil), "south")
             )
    end
  end

  # ---------- 7. 商剑鸣 combat.apply ----------

  describe "商剑鸣 combat.apply（LPC ming.c:122-124）" do
    test "combat_config 与运行时 temp 都带 damage 100 / armor 200", %{world: world} do
      ob = npc(world, "shang jianming")
      temp = ob.meta.combat.temp

      # attach_npc_applies 把 combat.apply 合并进 combat.temp（damage 缺省补 unarmed_damage）
      assert temp[:damage] == 100
      assert temp[:armor] == 200

      # npc_combat_config 也保留一份 apply（供战斗/复活重建使用）
      assert ob.meta.combat_config.apply[:damage] == 100
      assert ob.meta.combat_config.apply[:armor] == 200
    end
  end
end
