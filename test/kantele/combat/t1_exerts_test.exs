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
    {"zixia-shengong", "powerup", "zixia-shengong", %{attack: 33, defense: 33}, "你的内力不够。\n"}
  ]

  @skills ~w(bahuang-gong beiming-shengong bibo-shengong changsheng-jue hunyuan-yiqi
             taiji-shengong xiaowuxiang xuanming-shengong zhanshen-xinjing
             xuantian-wujigong shenghuo-shengong shenghuo-xinfa xuanmen-neigong zixia-shengong)

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
  end
end
