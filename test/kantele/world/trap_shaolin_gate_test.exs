defmodule Kantele.World.Trap.ShaolinGateTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.Trap
  alias Kantele.World.Trap.ShaolinGate

  @room %Kantele.World.Room{id: "shaolin:guangchang1"}

  defp mover(overrides \\ %{}) do
    meta =
      Map.merge(
        %PlayerMeta{
          family: %{name: "少林派", class: "bonze"},
          env: %{gender: "男性", K_record: 2, shen_record: 100},
          stats: %Stats{shen: 50},
          combat: %{WPK: 2},
          guilty: 0
        },
        overrides
      )

    %Kalevala.Character{id: "player-1", name: "虚张", meta: meta, inventory: []}
  end

  defp result(mover, dir \\ "north"), do: ShaolinGate.evaluate(mover, dir, @room)

  test "非 north → 放行，零副作用" do
    assert {:allow, []} = result(mover(), "south")
  end

  test "少林俗家弟子 → 拒绝原文" do
    mover = mover(%{family: %{name: "少林派"}})
    assert {:block, "壮年僧人说道：对不起，俗家弟子不得入寺修行。\n", []} = result(mover)
  end

  test "清净比丘（guilty=0 且 K_record==WPK）→ 放行 + 师兄辛苦了" do
    assert {:allow, [{:text, "壮年僧人侧身让开，说道：师兄辛苦了，请进。\n"}]} = result(mover())
  end

  test "破戒（shen_record>shen）→ guilty=1 + 记录重置 + 强制传送戒律院" do
    assert {:block, "壮年僧人沉下脸来，说道：戒律院主持玄痛大师请师兄去戒律院陈述此行过犯。\n",
            effects} = result(mover(%{env: %{gender: "男性", K_record: 9, shen_record: 100}}))

    assert {:set_guilty, 1} in effects
    assert {:set_env, :K_record, 2} in effects
    assert {:set_env, :shen_record, 50} in effects
    assert {:force_move, "shaolin:smdian"} in effects
  end

  test "破戒（shen_record<=shen）→ guilty=2" do
    assert {:block, _, effects} = result(mover(%{env: %{gender: "男性", K_record: 9, shen_record: 10}}))
    assert {:set_guilty, 2} in effects
  end

  test "已判过戒（guilty>0）→ 不再改 guilty/记录，直接送戒律院" do
    assert {:block, _, effects} = result(mover(%{guilty: 1}))

    refute Enum.any?(effects, &match?({:set_guilty, _}, &1))
    refute Enum.any?(effects, &match?({:set_env, _, _}, &1))
    assert {:force_move, "shaolin:smdian"} in effects
  end

  test "非少林 + 英雄令 → 贵客放行" do
    item = %Kalevala.World.Item{
      id: "shaolin:tie_ling",
      name: "少林英雄令",
      meta: %{aliases: ["yingxiong ling", "英雄令"]}
    }

    inst = %Kalevala.World.Item.Instance{item_id: "shaolin:tie_ling", item: item}
    mover = %{mover(%{family: nil}) | inventory: [inst]}

    assert {:allow, [{:text, "壮年僧人合十为礼，侧身让开，说道：原来是贵客驾到，请进请进。\n"}]} =
             result(mover)
  end

  test "非少林 + shen>=0 + 女性 → 女客拒绝" do
    mover = mover(%{family: nil, env: %{gender: "女性", K_record: 0, shen_record: 0}})
    assert {:block, "壮年僧人说道：这位女施主还是请回罢，本寺从不接待女客。\n", []} = result(mover)
  end

  test "非少林 + shen>=0 + 男性 → 俗人拒绝" do
    mover = mover(%{family: nil})
    assert {:block, "壮年僧人说道：这位施主请回罢，本寺不接待俗人。\n", []} = result(mover)
  end

  test "非少林 + shen<0 → 邪魔外道戒刀文案" do
    mover = mover(%{family: nil, stats: %Stats{shen: -1}})
    assert {:block, text, []} = result(mover)
    assert String.contains?(text, "你等邪魔外道")
    assert String.contains?(text, "斩断你们的狗腿")
  end

  test "Trap.dispatch 由 UCL condition 触发 shaolin_gate" do
    room = %{
      @room
      | exit_vetoes: [%{direction: "north", condition: "shaolin_gate(me, dir)", message: "x"}]
    }

    assert {:block, _, []} = Trap.dispatch(room, mover(%{family: %{name: "少林派"}}), "north")
  end
end
