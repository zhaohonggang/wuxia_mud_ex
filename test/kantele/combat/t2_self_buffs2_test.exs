defmodule Kantele.Combat.T2SelfBuffs2Test do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.PerformCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills

  alias Kantele.Combat.Skills.BanruoZhang
  alias Kantele.Combat.Skills.LongxingJian
  alias Kantele.Combat.Skills.RanmuDaofa
  alias Kantele.Combat.Skills.RiyueLun
  alias Kantele.Combat.Skills.ShenxingBaibian
  alias Kantele.Combat.Skills.TaijiJian

  @vitals %{Vitals.new() | neili: 2000, max_neili: 2000}
  @room "lingjiu:yard"

  defp build_character(opts) do
    stats =
      struct(
        Stats.new(),
        Keyword.take(opts, [:skills, :mapped, :performs]) |> Keyword.put_new(:performs, MapSet.new())
      )

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: @room,
      meta: %Kantele.Character.PlayerMeta{
        vitals: Keyword.get(opts, :vitals, @vitals),
        stats: stats,
        combat: Keyword.get(opts, :combat, Combat.new()),
        team: Keyword.get(opts, :team)
      }
    }
  end

  defp enemy, do: %{id: "mob-1", pid: self(), name: "恶犬", room_id: @room}

  defp with_buff(character, key, applies \\ []) do
    combat = %{character.meta.combat | buffs: [%Combat.Buff{key: key, applies: applies}]}
    %{character | meta: %{character.meta | combat: combat}}
  end

  defp with_temp(character, adds) do
    combat = %{character.meta.combat | temp: Map.merge(character.meta.combat.temp, adds)}
    %{character | meta: %{character.meta | combat: combat}}
  end

  defp fighter(opts, skill_type \\ "staff") do
    character = build_character(opts)

    combat =
      character.meta.combat
      |> Combat.equip(:weapon, %{name: "兵刃", skill_type: skill_type})
      |> Map.put(:enemies, [enemy()])

    %{character | meta: %{character.meta | combat: combat}}
  end

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
    |> Enum.flat_map(fn
      {:publish, _channel, %Kalevala.Event{topic: Kalevala.Event.Message, data: data}, _, _} -> [data.text]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp perform(opts, skill_id, move, skill_type) do
    opts = Keyword.put_new(opts, :performs, MapSet.new(["#{skill_id}/#{move}"]))
    PerformCommand.run(build_conn(fighter(opts, skill_type)), %{"action" => "#{skill_id}.#{move}"})
  end

  describe "T2 批次 2 技能注册" do
    test "6 门新技能已注册且可 enable 对应用法" do
      assert Skills.get("banruo-zhang") == BanruoZhang
      assert BanruoZhang.valid_enable("strike") and BanruoZhang.valid_enable("parry")
      refute BanruoZhang.valid_enable("staff")

      assert Skills.get("longxing-jian") == LongxingJian
      assert LongxingJian.valid_enable("sword")
      assert LongxingJian.valid_enable("staff") and LongxingJian.valid_enable("parry")

      assert Skills.get("ranmu-daofa") == RanmuDaofa
      assert RanmuDaofa.valid_enable("blade") and RanmuDaofa.valid_enable("parry")

      assert Skills.get("riyue-lun") == RiyueLun
      assert RiyueLun.valid_enable("hammer") and RiyueLun.valid_enable("parry")
      refute RiyueLun.valid_enable("blade")

      assert Skills.get("shenxing-baibian") == ShenxingBaibian
      assert ShenxingBaibian.valid_enable("dodge") and ShenxingBaibian.valid_enable("move")

      assert Skills.get("taiji-jian") == TaijiJian
      assert TaijiJian.valid_enable("sword") and TaijiJian.valid_enable("parry")
    end

    test "perform_list 映射正确" do
      assert BanruoZhang.perform_list() == %{"feng" => Kantele.Combat.Skills.Performs.BanruoZhang.Feng}
      assert LongxingJian.perform_list() == %{"xian" => Kantele.Combat.Skills.Performs.LongxingJian.Xian, "kong" => Kantele.Combat.Skills.Performs.LongxingJian.Kong}
      assert RanmuDaofa.perform_list() == %{"zhenyan" => Kantele.Combat.Skills.Performs.RanmuDaofa.Zhenyan}
      assert RiyueLun.perform_list() == %{"yuan" => Kantele.Combat.Skills.Performs.RiyueLun.Yuan}
      assert ShenxingBaibian.perform_list() == %{
               "piao" => Kantele.Combat.Skills.Performs.ShenxingBaibian.Piao
             }
      assert TaijiJian.perform_list() == %{"sui" => Kantele.Combat.Skills.Performs.TaijiJian.Sui, "chan" => Kantele.Combat.Skills.Performs.TaijiJian.Chan, "zhuan" => Kantele.Combat.Skills.Performs.TaijiJian.Zhuan}
    end
  end

  describe "般若掌·封魔" do
    test "未学会被拒" do
      conn = perform([skills: %{"banruo-zhang" => 60}, performs: MapSet.new()], "banruo-zhang", "feng", "staff")
      assert output_text(conn) =~ "外功中没有这种功能"
    end

    test "掌法不足被拒" do
      conn = perform([skills: %{"banruo-zhang" => 59}], "banruo-zhang", "feng", "staff")
      assert output_text(conn) =~ "不够娴熟"
    end

    test "内力不足被拒" do
      conn =
        perform(
          [skills: %{"banruo-zhang" => 60}, vitals: %{@vitals | neili: 199}],
          "banruo-zhang",
          "feng",
          "staff"
        )

      assert output_text(conn) =~ "真气不够"
    end

    test "已运功则拒绝" do
      character =
        fighter(skills: %{"banruo-zhang" => 60}, performs: MapSet.new(["banruo-zhang/feng"]))
        |> with_buff("brz_feng")

      conn = PerformCommand.run(build_conn(character), %{"action" => "banruo-zhang.feng"})
      assert output_text(conn) =~ "你已经在运功中了"
    end

    test "成功：闪避增/攻击减/扣内力/战斗中忙乱 2" do
      conn = perform([skills: %{"banruo-zhang" => 120}], "banruo-zhang", "feng", "staff")

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 1900
      assert updated.meta.combat.temp.dodge == 40
      assert updated.meta.combat.temp.attack == -30
      assert updated.meta.combat.busy == 2
      assert Combat.buff_active?(updated.meta.combat, "brz_feng")
      assert published_text(conn) =~ "封魔"
    end

    test "未战斗中不忙乱" do
      character = build_character(skills: %{"banruo-zhang" => 120}, performs: MapSet.new(["banruo-zhang/feng"]))

      conn = PerformCommand.run(build_conn(character), %{"action" => "banruo-zhang.feng"})
      assert conn.private.update_character.meta.combat.busy == 0
    end
  end

  describe "龙形剑法·神龙再现" do
    test "未学会被拒" do
      conn =
        perform([skills: %{"longxing-jian" => 150}, performs: MapSet.new()], "longxing-jian", "xian", "sword")

      assert output_text(conn) =~ "外功中没有这种功能"
    end

    test "战斗外被拒" do
      character =
        build_character(
          skills: %{"longxing-jian" => 150, "buddhism" => 150},
          performs: MapSet.new(["longxing-jian/xian"])
        )

      conn = PerformCommand.run(build_conn(character), %{"action" => "longxing-jian.xian"})
      assert output_text(conn) =~ "只能在战斗中使用"
    end

    test "剑法不足被拒" do
      conn = perform([skills: %{"longxing-jian" => 149, "buddhism" => 150}], "longxing-jian", "xian", "sword")
      assert output_text(conn) =~ "不够娴熟"
    end

    test "佛法不足被拒" do
      conn = perform([skills: %{"longxing-jian" => 150, "buddhism" => 149}], "longxing-jian", "xian", "sword")
      assert output_text(conn) =~ "佛法修为不够"
    end

    test "计数饱和被拒（xian 已累积 50）" do
      character =
        fighter(
          skills: %{"longxing-jian" => 150, "buddhism" => 150},
          performs: MapSet.new(["longxing-jian/xian"]),
          team: nil
        )
        |> with_temp(%{xian: 50})

      conn = PerformCommand.run(build_conn(character), %{"action" => "longxing-jian.xian"})
      assert output_text(conn) =~ "神龙已经厌倦"
    end

    test "成功：三属性微加成/计数 +1/扣内力/忙乱 1" do
      conn = perform([skills: %{"longxing-jian" => 150, "buddhism" => 150}], "longxing-jian", "xian", "sword")

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 1900
      assert updated.meta.combat.temp.attack == 2
      assert updated.meta.combat.temp.dodge == 1
      assert updated.meta.combat.temp.parry == 1
      assert updated.meta.combat.temp.xian == 1
      assert updated.meta.combat.busy == 1
      assert published_text(conn) =~ "神龙从天而降"
    end

    test "可叠放：再施一次计数 +2" do
      character =
        fighter(
          skills: %{"longxing-jian" => 150, "buddhism" => 150},
          performs: MapSet.new(["longxing-jian/xian"]),
          vitals: @vitals,
          team: nil
        )
        |> with_temp(%{attack: 2, dodge: 1, parry: 1, xian: 1})

      conn = PerformCommand.run(build_conn(character), %{"action" => "longxing-jian.xian"})
      updated = conn.private.update_character
      assert updated.meta.combat.temp.xian == 2
      assert updated.meta.combat.temp.attack == 4
    end
  end

  describe "燃木刀法·燃木真焰" do
    test "武器不对被拒（须持刀）" do
      conn =
        perform(
          [skills: %{"ranmu-daofa" => 180}],
          "ranmu-daofa",
          "zhenyan",
          "sword"
        )

      assert output_text(conn) =~ "必须用刀法"
    end

    test "未激发少林内功被拒" do
      conn =
        perform(
          [
            skills: %{"ranmu-daofa" => 180},
            mapped: %{"blade" => "ranmu-daofa", "force" => "bibo-shengong"},
            vitals: %{@vitals | max_neili: 2500}
          ],
          "ranmu-daofa",
          "zhenyan",
          "blade"
        )

      assert output_text(conn) =~ "没有激发少林内功"
    end

    test "未激发燃木刀法被拒" do
      conn =
        perform(
          [
            skills: %{"ranmu-daofa" => 180},
            mapped: %{"blade" => "cibei-dao", "force" => "hunyuan-yiqi"},
            vitals: %{@vitals | max_neili: 2500}
          ],
          "ranmu-daofa",
          "zhenyan",
          "blade"
        )

      assert output_text(conn) =~ "没有激发燃木刀法"
    end

    test "内力修为不足被拒" do
      conn =
        perform(
          [
            skills: %{"ranmu-daofa" => 180},
            mapped: %{"blade" => "ranmu-daofa", "force" => "hunyuan-yiqi"},
            vitals: %{@vitals | max_neili: 2499}
          ],
          "ranmu-daofa",
          "zhenyan",
          "blade"
        )

      assert output_text(conn) =~ "内力修为不足"
    end

    test "真气不足被拒" do
      conn =
        perform(
          [
            skills: %{"ranmu-daofa" => 180},
            mapped: %{"blade" => "ranmu-daofa", "force" => "hunyuan-yiqi"},
            vitals: %{@vitals | neili: 499, max_neili: 2500}
          ],
          "ranmu-daofa",
          "zhenyan",
          "blade"
        )

      assert output_text(conn) =~ "真气不足"
    end

    test "已运功则拒绝" do
      character =
        fighter(
          [skills: %{"ranmu-daofa" => 180}, mapped: %{"blade" => "ranmu-daofa", "force" => "hunyuan-yiqi"}, performs: MapSet.new(["ranmu-daofa/zhenyan"]), team: nil],
          "blade"
        )
        |> with_buff("zhen_yan")

      conn = PerformCommand.run(build_conn(character), %{"action" => "ranmu-daofa.zhenyan"})
      assert output_text(conn) =~ "无法连续施展"
    end

    test "成功：全属性加成/扣内力/战斗中忙乱 2" do
      conn =
        perform(
          [
            skills: %{"ranmu-daofa" => 180},
            mapped: %{"blade" => "ranmu-daofa", "force" => "hunyuan-yiqi"},
            vitals: %{@vitals | max_neili: 2500}
          ],
          "ranmu-daofa",
          "zhenyan",
          "blade"
        )

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 1600
      assert updated.meta.combat.temp.attack == div(180 * 2, 5)
      assert updated.meta.combat.temp.defense == div(180 * 2, 5)
      assert updated.meta.combat.temp.damage == div(180, 4)
      assert updated.meta.combat.busy == 2
      assert Combat.buff_active?(updated.meta.combat, "zhen_yan")
      assert published_text(conn) =~ "燃木真焰"
    end
  end

  describe "日月轮法·圆满势" do
    test "武器不对被拒（须持锤）" do
      conn = perform([skills: %{"riyue-lun" => 120}], "riyue-lun", "yuan", "sword")
      assert output_text(conn) =~ "武器不对"
    end

    test "未激发日月轮法被拒" do
      conn =
        perform(
          [skills: %{"riyue-lun" => 120}, mapped: %{"hammer" => "longxing-jian", "force" => "longxiang-gong"}],
          "riyue-lun",
          "yuan",
          "hammer"
        )

      assert output_text(conn) =~ "没有激发日月轮法"
    end

    test "未激发龙象般若功被拒" do
      conn =
        perform(
          [skills: %{"riyue-lun" => 120}, mapped: %{"hammer" => "riyue-lun", "force" => "hunyuan-yiqi"}],
          "riyue-lun",
          "yuan",
          "hammer"
        )

      assert output_text(conn) =~ "没有激发龙象般若功"
    end

    test "火候不足被拒" do
      conn =
        perform(
          [
            skills: %{"riyue-lun" => 119, "force" => 180},
            mapped: %{"hammer" => "riyue-lun", "force" => "longxiang-gong"}
          ],
          "riyue-lun",
          "yuan",
          "hammer"
        )

      assert output_text(conn) =~ "火候不足"
    end

    test "已运功则拒绝" do
      character =
        fighter(
          skills: %{"riyue-lun" => 120, "force" => 180},
          mapped: %{"hammer" => "riyue-lun", "force" => "longxiang-gong"},
          performs: MapSet.new(["riyue-lun/yuan"]),
          team: nil
        )
        |> with_buff("yuan_man")

      conn = PerformCommand.run(build_conn(character), %{"action" => "riyue-lun.yuan"})
      assert output_text(conn) =~ "你现在正在施展"
    end

    test "成功：招架加成/扣内力/战斗中忙乱 2" do
      conn =
        perform(
          [
            skills: %{"riyue-lun" => 120, "force" => 180},
            mapped: %{"hammer" => "riyue-lun", "force" => "longxiang-gong"}
          ],
          "riyue-lun",
          "yuan",
          "hammer"
        )

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 1800
      assert updated.meta.combat.temp.parry == 40
      assert updated.meta.combat.busy == 2
      assert Combat.buff_active?(updated.meta.combat, "yuan_man")
      assert published_text(conn) =~ "圆满势"
    end
  end

  describe "神行百变·虚无缥缈" do
    test "未学会被拒" do
      conn =
        perform([skills: %{"shenxing-baibian" => 60}, performs: MapSet.new()], "shenxing-baibian", "piao", "staff")

      assert output_text(conn) =~ "外功中没有这种功能"
    end

    test "轻功不足被拒" do
      conn = perform([skills: %{"shenxing-baibian" => 59}], "shenxing-baibian", "piao", "staff")
      assert output_text(conn) =~ "不够娴熟"
    end

    test "未激发神行百变被拒" do
      conn =
        perform(
          [skills: %{"shenxing-baibian" => 60}, mapped: %{"dodge" => "lingbo-weibu"}],
          "shenxing-baibian",
          "piao",
          "staff"
        )

      assert output_text(conn) =~ "没有使用神行百变"
    end

    test "内力不足被拒" do
      conn =
        perform(
          [skills: %{"shenxing-baibian" => 60}, mapped: %{"dodge" => "shenxing-baibian"}, vitals: %{@vitals | neili: 59}],
          "shenxing-baibian",
          "piao",
          "staff"
        )

      assert output_text(conn) =~ "真气不够"
    end

    test "已运功则拒绝" do
      character =
        fighter(
          skills: %{"shenxing-baibian" => 60},
          mapped: %{"dodge" => "shenxing-baibian"},
          performs: MapSet.new(["shenxing-baibian/piao"]),
          team: nil
        )
        |> with_buff("shenxing")

      conn = PerformCommand.run(build_conn(character), %{"action" => "shenxing-baibian.piao"})
      assert output_text(conn) =~ "你已经运起"
    end

    test "成功：闪避+skill/扣内力/无忙乱" do
      conn =
        perform(
          [skills: %{"shenxing-baibian" => 60}, mapped: %{"dodge" => "shenxing-baibian"}],
          "shenxing-baibian",
          "piao",
          "staff"
        )

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 1900
      assert updated.meta.combat.temp.dodge == 60
      assert updated.meta.combat.busy == 0
      assert Combat.buff_active?(updated.meta.combat, "shenxing")
      assert published_text(conn) =~ "飘渺不定"
    end
  end

  describe "太极剑法·随字诀" do
    test "武器不对被拒（须持剑）" do
      conn = perform([skills: %{"taiji-jian" => 60}], "taiji-jian", "sui", "blade")
      assert output_text(conn) =~ "武器不对"
    end

    test "未激发太极剑法被拒" do
      conn =
        perform(
          [skills: %{"taiji-jian" => 60}, mapped: %{"sword" => "huashan-jian"}],
          "taiji-jian",
          "sui",
          "sword"
        )

      assert output_text(conn) =~ "没有激发太极剑法"
    end

    test "剑法不足被拒" do
      conn =
        perform(
          [skills: %{"taiji-jian" => 59}, mapped: %{"sword" => "taiji-jian"}],
          "taiji-jian",
          "sui",
          "sword"
        )

      assert output_text(conn) =~ "不够娴熟"
    end

    test "内力不足被拒" do
      conn =
        perform(
          [
            skills: %{"taiji-jian" => 60},
            mapped: %{"sword" => "taiji-jian"},
            vitals: %{@vitals | neili: 299}
          ],
          "taiji-jian",
          "sui",
          "sword"
        )

      assert output_text(conn) =~ "真气不足"
    end

    test "已运功则拒绝" do
      character =
        fighter(
          skills: %{"taiji-jian" => 60},
          mapped: %{"sword" => "taiji-jian"},
          performs: MapSet.new(["taiji-jian/sui"]),
          team: nil
        )
        |> with_buff("tjj_sui")

      conn = PerformCommand.run(build_conn(character), %{"action" => "taiji-jian.sui"})
      assert output_text(conn) =~ "你现在正在施展"
    end

    test "成功：防御增/攻击减/扣内力/战斗中忙乱 3" do
      conn =
        perform([skills: %{"taiji-jian" => 60}, mapped: %{"sword" => "taiji-jian"}], "taiji-jian", "sui", "sword")

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 1900
      assert updated.meta.combat.temp.defense == 20
      assert updated.meta.combat.temp.attack == -10
      assert updated.meta.combat.busy == 3
      assert Combat.buff_active?(updated.meta.combat, "tjj_sui")
      assert published_text(conn) =~ "「随」字诀"
    end
  end
end