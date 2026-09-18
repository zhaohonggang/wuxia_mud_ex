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
    {"zhanshen-xinjing", "shield", "zhanshen-xinjing", %{armor: 50}, "你的内力不够。\n"}
  ]

  @skills ~w(bahuang-gong beiming-shengong bibo-shengong changsheng-jue hunyuan-yiqi
             taiji-shengong xiaowuxiang xuanming-shengong zhanshen-xinjing)

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

  test "powerup/shield 成功：扣 100 内力 + 加成 + buff 回收值" do
    for {skill_id, function, _level_skill, expected, _message} <- @cases do
      skills = %{"force" => 100, skill_id => 100}

      conn =
        Simple.run(build_conn(player(skills: skills)), exert(skill_id, function).spec(), fn _ ->
          1
        end)

      char = conn.private.update_character

      assert char.meta.vitals.neili == 8900, "#{skill_id}/#{function} 内力"
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
  end

  test "新内功 valid_learn 门槛" do
    stats = fn skills, con ->
      struct(Kantele.Character.Stats.new(), %{skills: skills, con: con})
    end

    taiji = Skills.get("taiji-shengong")
    assert taiji.valid_learn(stats.(%{"force" => 100, "taoism" => 100}, 20)) == :ok
    assert {:error, _} = taiji.valid_learn(stats.(%{"force" => 99, "taoism" => 100}, 20))
    assert {:error, _} = taiji.valid_learn(stats.(%{"force" => 100, "taoism" => 99}, 20))

    assert {:error, _} =
             taiji.valid_learn(
               stats.(%{"force" => 100, "taoism" => 100, "taiji-shengong" => 200}, 20)
             )

    xiaowuxiang = Skills.get("xiaowuxiang")
    assert xiaowuxiang.valid_learn(stats.(%{"force" => 80}, 20)) == :ok
    assert {:error, _} = xiaowuxiang.valid_learn(stats.(%{"force" => 79}, 20))

    xuanming = Skills.get("xuanming-shengong")
    assert xuanming.valid_learn(stats.(%{"force" => 100}, 32)) == :ok
    assert {:error, _} = xuanming.valid_learn(stats.(%{"force" => 100}, 31))
    assert {:error, _} = xuanming.valid_learn(stats.(%{"force" => 50}, 40))

    zhanshen = Skills.get("zhanshen-xinjing")
    assert zhanshen.valid_learn(stats.(%{"force" => 100}, 25)) == :ok
    assert {:error, _} = zhanshen.valid_learn(stats.(%{"force" => 100}, 24))
  end
end
