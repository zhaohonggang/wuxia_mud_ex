defmodule Kantele.Combat.T1ExertsTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Performs.Simple
  alias Kantele.Combat.Skills

  # {技能, 运功, 取等级的技能, 期望临时加成, 内力不足文案}
  @cases [
    {"bahuang-gong", "powerup", "bahuang-gong", %{attack: 50, dodge: 33, parry: 33}, "你的内力不够。\n"},
    {"bahuang-gong", "shield", "bahuang-gong", %{armor: 50}, "你的内力不够。\n"},
    {"beiming-shengong", "powerup", "beiming-shengong", %{attack: 33, defense: 33}, "你的内力不够!"},
    {"beiming-shengong", "shield", "beiming-shengong", %{armor: 50}, "你的内力不够。\n"},
    {"changsheng-jue", "powerup", "force", %{attack: 40, parry: 40, dodge: 40}, "你的内力不够。\n"},
    {"changsheng-jue", "shield", "force", %{armor: 300}, "你的内力不够。\n"},
    {"bibo-shengong", "powerup", "bibo-shengong", %{attack: 33, defense: 33}, "你的真气不够！"},
    {"hunyuan-yiqi", "powerup", "hunyuan-yiqi", %{attack: 33, defense: 33}, "你的内力不够。\n"},
    {"taiji-shengong", "powerup", "taiji-shengong", %{attack: 33, defense: 33}, "你的内力不够。\n"},
    {"taiji-shengong", "shield", "taiji-shengong", %{armor: 50}, "你的内力不够。\n"},
    {"xiaowuxiang", "powerup", "xiaowuxiang", %{attack: 33, parry: 33, dodge: 33}, "你的真气不够！"},
    {"xiaowuxiang", "shield", "xiaowuxiang", %{armor: 50}, "你的真气不够。\n"},
    {"xuanming-shengong", "powerup", "xuanming-shengong", %{attack: 33, defense: 33},
     "你的内力不够。\n"},
    {"xuanming-shengong", "shield", "xuanming-shengong", %{armor: 50}, "你的内力不够。\n"},
    {"zhanshen-xinjing", "powerup", "zhanshen-xinjing", %{attack: 33, defense: 33}, "你的内力不够了。"},
    {"zhanshen-xinjing", "shield", "zhanshen-xinjing", %{armor: 50}, "你的内力不够。\n"},
    {"xuantian-wujigong", "powerup", "xuantian-wujigong", %{attack: 33, defense: 33},
     "你的内力不够。\n"},
    {"xuantian-wujigong", "shield", "xuantian-wujigong", %{armor: 50}, "你的内力不够。\n"},
    {"shenghuo-shengong", "powerup", "shenghuo-shengong", %{attack: 33, dodge: 33, parry: 33},
     "你的内力不够。\n"},
    {"shenghuo-shengong", "shield", "shenghuo-shengong", %{armor: 50}, "你的真气不够。\n"},
    {"shenghuo-xinfa", "powerup", "force", %{attack: 16, dodge: 16, parry: 16}, "你的内力不够。\n"},
    {"xuanmen-neigong", "powerup", "xuanmen-neigong", %{attack: 25, dodge: 25, parry: 25},
     "你的内力不够。\n"},
    {"zixia-shengong", "powerup", "zixia-shengong", %{attack: 33, defense: 33}, "你的内力不够。\n"},
    {"bingxin-jue", "powerup", "force", %{attack: 33, defense: 33}, "你的真气不够！"},
    {"dahai-wuliang", "powerup", "force", %{attack: 33, defense: 33}, "你的内力不够了。"},
    {"duanshi-xinfa", "powerup", "force", %{attack: 20, defense: 20}, "你的内力不够。\n"},
    {"fushang-neigong", "powerup", "force", %{attack: 33, defense: 33}, "你的内力不够。\n"},
    {"huntian-qigong", "powerup", "force", %{attack: 33, defense: 33}, "你的真气不够。\n"},
    {"fenxin-jue", "powerup", "fenxin-jue", %{attack: 33, defense: 33}, "你的内力不够。\n"},
    {"hanbing-zhenqi", "powerup", "hanbing-zhenqi", %{attack: 33, defense: 33}, "你的内力不够。\n"},
    {"freezing-force", "powerup", "freezing-force", %{attack: 33, defense: 33}, "你的真气不够。\n"},
    {"kurong-changong", "powerup", "kurong-changong", %{attack: 33, defense: 33}, "你的内力不够。\n"},
    {"liangyi-shengong", "powerup", "liangyi-shengong", %{attack: 33, defense: 33}, "你的内力不够。\n"},
    {"luohan-fumogong", "powerup", "luohan-fumogong", %{attack: 33, defense: 33}, "你的内力不够。\n"},
    {"miaojia-neigong", "powerup", "miaojia-neigong", %{attack: 33, defense: 33}, "你的内力不够了。"},
    {"nei-bagua", "powerup", "nei-bagua", %{attack: 33, defense: 33, parry: 16}, "你的内力不够。\n"},
    {"wuwang-shengong", "powerup", "force", %{attack: 33, defense: 33}, "你的内力不够。\n"}
  ]

  @skills ~w(bahuang-gong beiming-shengong bibo-shengong changsheng-jue hunyuan-yiqi
             taiji-shengong xiaowuxiang xuanming-shengong zhanshen-xinjing
             xuantian-wujigong shenghuo-shengong shenghuo-xinfa xuanmen-neigong zixia-shengong
             bingxin-jue dahai-wuliang duanshi-xinfa fushang-neigong huntian-qigong fenxin-jue
             hanbing-zhenqi freezing-force kurong-changong liangyi-shengong luohan-fumogong
             miaojia-neigong nei-bagua wuwang-shengong)

  defp player(opts) do
    skills = Keyword.get(opts, :skills, %{"force" => 100})

    stats = struct(Kantele.Character.Stats.new(), %{skills: skills})
    vitals = %{Vitals.new() | neili: Keyword.get(opts, :neili, 9000), max_neili: 10000}

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %Kantele.Character.PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Keyword.get(opts, :combat, Combat.new())
      }
    }
  end

  defp exert(skill_id, function), do: Skills.get(skill_id).exert_list()[function]

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp published_text(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn change ->
      match?({:publish, _, %Kalevala.Event{topic: Kalevala.Event.Message}, _, _}, change)
    end)
    |> Enum.map(fn {:publish, _channel, event, _opts, _error} -> event.data.text end)
    |> Enum.join("")
  end

  test "内功已注册且挂载 exert" do
    for id <- @skills do
      module = Skills.get(id)
      assert module, "missing skill #{id}"
      assert map_size(module.exert_list()) >= 1
    end
  end

  test "powerup/shield 成功：扣对应内力 + 加成 + buff 回收值" do
    for {skill_id, function, _level_skill, expected, _message} <- @cases do
      skills = %{"force" => 100, skill_id => 100}
      spec = exert(skill_id, function).spec()

      conn = Simple.run(build_conn(player(skills: skills)), spec, fn _ -> 1 end)
      char = conn.private.update_character

      assert char.meta.vitals.neili == 9000 - Map.get(spec.costs, :neili, 0),
             "#{skill_id}/#{function} 内力"

      assert Combat.buff_active?(char.meta.combat, function), "#{skill_id}/#{function} buff"

      assert Map.take(char.meta.combat.temp, Map.keys(expected)) == expected,
             "#{skill_id}/#{function} 加成"

      buff = Enum.find(char.meta.combat.buffs, &(&1.key == function))
      assert buff.applies == Map.new(expected, fn {key, value} -> {key, -value} end)
    end
  end

  test "内力不足：渲染各自文案且不落库" do
    for {skill_id, function, _level_skill, _expected, message} <- @cases do
      conn =
        Simple.run(build_conn(player(neili: 0)), exert(skill_id, function).spec(), fn _ -> 1 end)

      assert output_text(conn) =~ message, "#{skill_id}/#{function} 文案"
      assert is_nil(conn.private.update_character)
    end
  end

  test "shield 修为门槛与运功中互斥" do
    shield = exert("bahuang-gong", "shield").spec()
    low = %{"bahuang-gong" => 10, "force" => 100}

    conn = Simple.run(build_conn(player(skills: low)), shield, fn _ -> 1 end)
    assert output_text(conn) =~ "八荒六合唯我独尊功修为不够"

    combat = %{Combat.new() | buffs: [%Combat.Buff{key: "shield", applies: []}]}
    skills = %{"bahuang-gong" => 100, "force" => 100}

    conn = Simple.run(build_conn(player(skills: skills, combat: combat)), shield, fn _ -> 1 end)
    assert output_text(conn) =~ "你已经在运功中了"
  end

  test "战斗中 busy：powerup 随机 1..3、changsheng shield 固定 2" do
    fight = %{Combat.new() | enemies: [%{id: "e1", pid: self(), name: "敌", room_id: "test:room"}]}

    conn =
      Simple.run(
        build_conn(player(skills: %{"bahuang-gong" => 100, "force" => 100}, combat: fight)),
        exert("bahuang-gong", "powerup").spec(),
        fn _ -> 3 end
      )

    assert conn.private.update_character.meta.combat.busy == 3

    conn =
      Simple.run(
        build_conn(player(skills: %{"changsheng-jue" => 100, "force" => 100}, combat: fight)),
        exert("changsheng-jue", "shield").spec(),
        fn _ -> 1 end
      )

    assert conn.private.update_character.meta.combat.busy == 2

    conn =
      Simple.run(
        build_conn(player(skills: %{"xuantian-wujigong" => 100, "force" => 100}, combat: fight)),
        exert("xuantian-wujigong", "powerup").spec(),
        fn _ -> 1 end
      )

    assert conn.private.update_character.meta.combat.busy == 3
  end

  test "新内功 valid_learn 门槛" do
    build = fn attrs -> struct(Kantele.Character.Stats.new(), attrs) end
    skills = fn map -> build.(%{skills: map, con: 20, int: 20}) end

    taiji = Skills.get("taiji-shengong")
    assert taiji.valid_learn(skills.(%{"force" => 100, "taoism" => 100})) == :ok
    assert {:error, _} = taiji.valid_learn(skills.(%{"force" => 99, "taoism" => 100}))
    assert {:error, _} = taiji.valid_learn(skills.(%{"force" => 100, "taoism" => 99}))

    assert {:error, _} =
             taiji.valid_learn(
               skills.(%{"force" => 100, "taoism" => 100, "taiji-shengong" => 200})
             )

    xiaowuxiang = Skills.get("xiaowuxiang")
    assert xiaowuxiang.valid_learn(skills.(%{"force" => 80})) == :ok
    assert {:error, _} = xiaowuxiang.valid_learn(skills.(%{"force" => 79}))

    xuanming = Skills.get("xuanming-shengong")
    assert xuanming.valid_learn(build.(%{skills: %{"force" => 100}, con: 32})) == :ok
    assert {:error, _} = xuanming.valid_learn(build.(%{skills: %{"force" => 100}, con: 31}))
    assert {:error, _} = xuanming.valid_learn(build.(%{skills: %{"force" => 50}, con: 40}))

    zhanshen = Skills.get("zhanshen-xinjing")
    assert zhanshen.valid_learn(build.(%{skills: %{"force" => 100}, con: 25})) == :ok
    assert {:error, _} = zhanshen.valid_learn(build.(%{skills: %{"force" => 100}, con: 24}))

    for id <- ~w(xuantian-wujigong xuanmen-neigong zixia-shengong) do
      module = Skills.get(id)
      assert module.valid_learn(skills.(%{"force" => 60})) == :ok
      assert {:error, _} = module.valid_learn(skills.(%{"force" => 59}))
    end

    xinfa = Skills.get("shenghuo-xinfa")
    assert xinfa.valid_learn(skills.(%{"force" => 10})) == :ok
    assert {:error, _} = xinfa.valid_learn(skills.(%{"force" => 9}))

    shenghuo = Skills.get("shenghuo-shengong")
    assert shenghuo.valid_learn(build.(%{skills: %{"force" => 180}, int: 32})) == :ok
    assert {:error, _} = shenghuo.valid_learn(build.(%{skills: %{"force" => 180}, int: 31}))
    assert {:error, _} = shenghuo.valid_learn(build.(%{skills: %{"force" => 179}, int: 40}))

    bingxin = Skills.get("bingxin-jue")
    assert bingxin.valid_learn(build.(%{skills: %{"force" => 100}, int: 26})) == :ok
    assert {:error, _} = bingxin.valid_learn(build.(%{skills: %{"force" => 100}, int: 25}))
    assert {:error, _} = bingxin.valid_learn(build.(%{skills: %{"force" => 99}, int: 30}))

    for id <- ~w(dahai-wuliang fushang-neigong) do
      module = Skills.get(id)
      assert module.valid_learn(skills.(%{"force" => 50})) == :ok
      assert {:error, _} = module.valid_learn(skills.(%{"force" => 49}))
    end

    assert Skills.get("huntian-qigong").valid_learn(skills.(%{"force" => 30})) == :ok
    assert {:error, _} = Skills.get("huntian-qigong").valid_learn(skills.(%{"force" => 29}))

    assert Skills.get("fenxin-jue").valid_learn(skills.(%{"force" => 70})) == :ok
    assert {:error, _} = Skills.get("fenxin-jue").valid_learn(skills.(%{"force" => 69}))

    assert Skills.get("duanshi-xinfa").valid_learn(skills.(%{})) == :ok
  end

  test "huntian-qigong/shield 无数值加成（LPC 用非 apply 的 str/dex 临时键）" do
    spec = exert("huntian-qigong", "shield").spec()
    skills = %{"huntian-qigong" => 200, "checking" => 10, "begging" => 5, "force" => 100}

    conn = Simple.run(build_conn(player(skills: skills)), spec, fn _ -> 1 end)
    char = conn.private.update_character

    assert char.meta.vitals.neili == 8900
    assert Combat.buff_active?(char.meta.combat, "shield")
    assert Enum.find(char.meta.combat.buffs, &(&1.key == "shield")).applies == %{}

    low = %{"huntian-qigong" => 100, "force" => 100}
    conn = Simple.run(build_conn(player(skills: low)), spec, fn _ -> 1 end)
    assert output_text(conn) =~ "你的混天气功修为不够"
  end

  test "第 5 批 valid_learn 门槛" do
    build = fn attrs -> struct(Kantele.Character.Stats.new(), attrs) end
    skills = fn map -> build.(%{skills: map, con: 20, int: 20}) end

    hanbing = Skills.get("hanbing-zhenqi")
    assert hanbing.valid_learn(skills.(%{"force" => 100})) == :ok

    assert {:error, _} = hanbing.valid_learn(skills.(%{"force" => 100, "hanbing-zhenqi" => 150}))

    freezing = Skills.get("freezing-force")
    assert freezing.valid_learn(skills.(%{"force" => 50})) == :ok
    assert {:error, _} = freezing.valid_learn(skills.(%{"force" => 49}))
    assert {:error, _} = freezing.valid_learn(skills.(%{"force" => 100, "freezing-force" => 120}))

    assert Skills.get("kurong-changong").valid_learn(skills.(%{})) == :ok

    for id <- ~w(liangyi-shengong wuwang-shengong) do
      module = Skills.get(id)
      assert module.valid_learn(skills.(%{"force" => 60})) == :ok
      assert {:error, _} = module.valid_learn(skills.(%{"force" => 59}))
    end

    luohan = Skills.get("luohan-fumogong")
    assert luohan.valid_learn(build.(%{skills: %{"force" => 100}, int: 30, con: 30})) == :ok

    assert {:error, _} =
             luohan.valid_learn(build.(%{skills: %{"force" => 100}, int: 29, con: 30}))

    assert {:error, _} =
             luohan.valid_learn(build.(%{skills: %{"force" => 100}, int: 30, con: 29}))

    assert {:error, _} = luohan.valid_learn(build.(%{skills: %{"force" => 99}, int: 30, con: 30}))

    assert Skills.get("miaojia-neigong").valid_learn(skills.(%{})) == :ok

    nei = Skills.get("nei-bagua")
    assert nei.valid_learn(skills.(%{"force" => 80, "wai-bagua" => 100})) == :ok
    assert {:error, _} = nei.valid_learn(skills.(%{"force" => 79, "wai-bagua" => 100}))
    assert {:error, _} = nei.valid_learn(skills.(%{"force" => 80, "wai-bagua" => 99}))
  end

  test "kurong-changong/powerup 文案按修为分档（message 函数）" do
    spec = exert("kurong-changong", "powerup").spec()

    high =
      Simple.run(
        build_conn(player(skills: %{"kurong-changong" => 300, "force" => 100})),
        spec,
        fn _ -> 1 end
      )

    assert published_text(high) =~ "一半犹如婴儿"

    mid =
      Simple.run(
        build_conn(player(skills: %{"kurong-changong" => 180, "force" => 100})),
        spec,
        fn _ -> 1 end
      )

    assert published_text(mid) =~ "树皮般干皱苍老"

    low =
      Simple.run(
        build_conn(player(skills: %{"kurong-changong" => 100, "force" => 100})),
        spec,
        fn _ -> 1 end
      )

    assert published_text(low) =~ "真气顿时游遍全身"
  end
end
