defmodule Kantele.Combat.T2SelfBuffsTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.FanliangyiEvent
  alias Kantele.Character.PerformCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills

  alias Kantele.Combat.Skills.CibeiDao
  alias Kantele.Combat.Skills.DamoJian
  alias Kantele.Combat.Skills.FanliangyiDao
  alias Kantele.Combat.Skills.HuashanJian
  alias Kantele.Combat.Skills.JingangBuhuaiti
  alias Kantele.Combat.Skills.JinzhongZhao
  alias Kantele.Combat.Skills.KuangfengJian
  alias Kantele.Combat.Skills.LingboWeibu

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

  describe "T2 批次 1 技能注册" do
    test "7 门新技能已注册且可 enable 对应用法" do
      assert Skills.get("cibei-dao") == CibeiDao
      assert CibeiDao.valid_enable("blade") and CibeiDao.valid_enable("parry")
      refute CibeiDao.valid_enable("sword")

      assert Skills.get("damo-jian") == DamoJian
      assert DamoJian.valid_enable("sword") and DamoJian.valid_enable("parry")

      assert Skills.get("fanliangyi-dao") == FanliangyiDao
      assert FanliangyiDao.valid_enable("blade") and FanliangyiDao.valid_enable("parry")

      assert Skills.get("jingang-buhuaiti") == JingangBuhuaiti
      assert JingangBuhuaiti.valid_enable("parry")
      refute JingangBuhuaiti.valid_enable("dodge")

      assert Skills.get("jinzhong-zhao") == JinzhongZhao
      assert JinzhongZhao.valid_enable("parry")

      assert Skills.get("lingbo-weibu") == LingboWeibu
      assert LingboWeibu.valid_enable("dodge")
      refute LingboWeibu.valid_enable("blade")

      assert Skills.get("kuangfeng-jian") == KuangfengJian
      assert KuangfengJian.valid_enable("sword") and KuangfengJian.valid_enable("parry")
    end

    test "perform_list 映射正确" do
      assert CibeiDao.perform_list() == %{"sheshen" => Kantele.Combat.Skills.Performs.CibeiDao.Sheshen}
      assert DamoJian.perform_list() == %{"qingxin" => Kantele.Combat.Skills.Performs.DamoJian.Qingxin}
      assert FanliangyiDao.perform_list() == %{"makearray" => Kantele.Combat.Skills.Performs.FanliangyiDao.Makearray}
      assert JingangBuhuaiti.perform_list() == %{"jingang" => Kantele.Combat.Skills.Performs.JingangBuhuaiti.Jingang}
      assert JinzhongZhao.perform_list() == %{"zhao" => Kantele.Combat.Skills.Performs.JinzhongZhao.Zhao}
      assert LingboWeibu.perform_list() == %{"ling" => Kantele.Combat.Skills.Performs.LingboWeibu.Ling}
      assert KuangfengJian.perform_list() == %{"sao" => Kantele.Combat.Skills.Performs.KuangfengJian.Sao}
      assert Map.has_key?(HuashanJian.perform_list(), "lian")
    end
  end

  describe "慈悲刀法·舍身喂鹰" do
    test "未学会被拒" do
      conn = perform([skills: %{"cibei-dao" => 80}, performs: MapSet.new()], "cibei-dao", "sheshen", "blade")
      assert output_text(conn) =~ "外功中没有这种功能"
    end

    test "刀法不足被拒" do
      conn = perform([skills: %{"cibei-dao" => 59}], "cibei-dao", "sheshen", "blade")
      assert output_text(conn) =~ "不够娴熟"
    end

    test "武器不对被拒（须持刀）" do
      conn = perform([skills: %{"cibei-dao" => 80}], "cibei-dao", "sheshen", "sword")
      assert output_text(conn) =~ "武器不对"
    end

    test "已运功则拒绝" do
      character =
        fighter(skills: %{"cibei-dao" => 80}, performs: MapSet.new(["cibei-dao/sheshen"]), vitals: @vitals, team: nil)
        |> with_buff("cbd_sheshen")

      conn = PerformCommand.run(build_conn(character), %{"action" => "cibei-dao.sheshen"})
      assert output_text(conn) =~ "你已经在运功中了"
    end

    test "成功：attack 加/闪避减/扣内力/战斗中忙乱 2" do
      conn = perform([skills: %{"cibei-dao" => 120}], "cibei-dao", "sheshen", "blade")

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 1900
      assert updated.meta.combat.temp.attack == div(120, 3)
      assert updated.meta.combat.temp.dodge == -div(120, 5)
      assert updated.meta.combat.busy == 2
      assert Combat.buff_active?(updated.meta.combat, "cbd_sheshen")
      assert published_text(conn) =~ "舍身喂鹰"
    end

    test "未战斗中不忙乱" do
      character = build_character(skills: %{"cibei-dao" => 120}, performs: MapSet.new(["cibei-dao/sheshen"]))

      combat =
        character.meta.combat |> Combat.equip(:weapon, %{name: "刀", skill_type: "blade"})

      character = %{character | meta: %{character.meta | combat: combat}}

      conn = PerformCommand.run(build_conn(character), %{"action" => "cibei-dao.sheshen"})
      assert conn.private.update_character.meta.combat.busy == 0
    end
  end

  describe "金刚不坏护体神功·jingang" do
    test "内力不足被拒" do
      conn =
        perform(
          [skills: %{"jingang-buhuaiti" => 100, "force" => 200}, vitals: %{@vitals | neili: 299}],
          "jingang-buhuaiti",
          "jingang",
          "staff"
        )

      assert output_text(conn) =~ "内力不够"
    end

    test "已运金钟罩则拒绝（互斥）" do
      character =
        fighter(
          skills: %{"jingang-buhuaiti" => 100, "force" => 200},
          performs: MapSet.new(["jingang-buhuaiti/jingang"]),
          vitals: @vitals,
          team: nil
        )
        |> with_buff("jinzhongzhao")

      conn = PerformCommand.run(build_conn(character), %{"action" => "jingang-buhuaiti.jingang"})
      assert output_text(conn) =~ "金钟罩"
    end

    test "成功：armor/force 加成与互斥 buff" do
      # total = force 200 + jingang-buhuaiti 100/2 = 250 → armor 125 / force 83
      conn =
        perform(
          [skills: %{"jingang-buhuaiti" => 100, "force" => 200}],
          "jingang-buhuaiti",
          "jingang",
          "staff"
        )

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 1800
      assert updated.meta.combat.temp.armor == 125
      assert updated.meta.combat.temp.force == 83
      assert updated.meta.combat.busy == 2
      assert Combat.buff_active?(updated.meta.combat, "jingangbuhuai")
      refute Combat.buff_active?(updated.meta.combat, "jinzhongzhao")
      assert published_text(conn) =~ "金光"
    end
  end

  describe "金钟罩·zhao" do
    test "修为不足被拒" do
      conn = perform([skills: %{"jinzhong-zhao" => 149, "force" => 350}], "jinzhong-zhao", "zhao", "staff")
      assert output_text(conn) =~ "修为不够"
    end

    test "已运金刚不坏则拒绝（互斥）" do
      character =
        fighter(
          skills: %{"jinzhong-zhao" => 200, "force" => 350},
          performs: MapSet.new(["jinzhong-zhao/zhao"]),
          vitals: @vitals,
          team: nil
        )
        |> with_buff("jingangbuhuai")

      conn = PerformCommand.run(build_conn(character), %{"action" => "jinzhong-zhao.zhao"})
      assert output_text(conn) =~ "金刚不坏护体神功"
    end

    test "成功：armor/force 加成与忙乱 3" do
      # total = force 350 + jinzhong-zhao 200/2 = 450 → armor 225 / force 112
      conn = perform([skills: %{"jinzhong-zhao" => 200, "force" => 350}], "jinzhong-zhao", "zhao", "staff")

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 1700
      assert updated.meta.combat.temp.armor == 225
      assert updated.meta.combat.temp.force == 112
      assert updated.meta.combat.busy == 3
      assert Combat.buff_active?(updated.meta.combat, "jinzhongzhao")
      assert published_text(conn) =~ "烟尘滚滚"
    end
  end

  describe "凌波微步·ling" do
    test "轻功不足被拒" do
      conn = perform([skills: %{"lingbo-weibu" => 119}], "lingbo-weibu", "ling", "staff")
      assert output_text(conn) =~ "不够熟练"
    end

    test "成功：扣内力挂 buff 并按修为档文案" do
      conn = perform([skills: %{"lingbo-weibu" => 200}], "lingbo-weibu", "ling", "staff")

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 1600
      assert updated.meta.combat.busy == 2
      assert Combat.buff_active?(updated.meta.combat, "lingbo")
      assert published_text(conn) =~ "洛神凌波"
      refute published_text(conn) =~ "宛如洛神再世"

      conn = perform([skills: %{"lingbo-weibu" => 301}], "lingbo-weibu", "ling", "staff")
      assert published_text(conn) =~ "宛如洛神再世"
    end
  end

  describe "达摩剑·清心剑（攻击方）" do
    test "未学会被拒" do
      conn = perform([skills: %{"damo-jian" => 220, "force" => 100}, performs: MapSet.new()], "damo-jian", "qingxin", "sword")
      assert output_text(conn) =~ "你不会使用"
    end

    test "剑法不足被拒" do
      conn = perform([skills: %{"damo-jian" => 199, "force" => 100}], "damo-jian", "qingxin", "sword")
      assert output_text(conn) =~ "不够娴熟"
    end

    test "未激发达摩剑被拒" do
      conn = perform([skills: %{"damo-jian" => 220, "force" => 100}], "damo-jian", "qingxin", "sword")
      assert output_text(conn) =~ "没有激发达摩剑法"
    end

    test "成功：扣 200 内力忙乱 1 并投递目标侧事件" do
      conn =
        perform(
          [skills: %{"damo-jian" => 220, "force" => 100, "sword" => 200}, mapped: %{"sword" => "damo-jian"}],
          "damo-jian",
          "qingxin",
          "sword"
        )

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 1800
      assert updated.meta.combat.busy == 1
      assert published_text(conn) =~ "剑气悄然而出"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "damo-jian/qingxin", ap: 300, attacker: %{id: "player-1"}}
      }
    end
  end

  describe "达摩剑·清心剑（目标侧结算）" do
    defp attacker, do: %{id: "player-1", pid: self(), name: "张三", room_id: @room}

    defp powered_target(force) do
      combat =
        %Combat{
          Combat.new()
          | buffs: [%Combat.Buff{key: "powerup", applies: []}],
            temp: %{attack: 30, defense: 20}
        }

      build_character(skills: %{"force" => force}, combat: combat)
    end

    defp incoming(target_conn, data) do
      CombatEvent.perform_incoming(target_conn, %{data: Map.merge(%{attacker: attacker()}, data)})
    end

    test "目标未 powerup：安然无恙不改动" do
      conn = incoming(build_conn(build_character(skills: %{"force" => 200})), %{perform_id: "damo-jian/qingxin", ap: 300})
      updated = conn.private.update_character
      refute Combat.buff_active?(updated.meta.combat, "damo-qingxin")
      assert published_text(conn) =~ "没有运用真气提升战力"
    end

    test "判定失败：内力深厚无变化" do
      # ap=600，dp=200*2=400；ap/2+rand(ap) 最小 300+1>400? → 用极小 ap 保证失败
      conn =
        incoming(build_conn(powered_target(200)), %{perform_id: "damo-jian/qingxin", ap: 100, rng: fn _ -> 1 end})

      updated = conn.private.update_character
      assert updated.meta.combat.temp.attack == 30
      assert updated.meta.combat.temp.defense == 20
      assert published_text(conn) =~ "内力深厚"
    end

    test "判定成功：抽走 attack/defense 加成并挂恢复 buff" do
      # ap=400，dp=200*2=400；ap/2+rand(ap)=200+rng，rng 高必中
      conn =
        incoming(build_conn(powered_target(200)), %{perform_id: "damo-jian/qingxin", ap: 400, rng: fn _ -> 400 end})

      updated = conn.private.update_character
      assert updated.meta.combat.temp.attack == 0
      assert updated.meta.combat.temp.defense == 0
      assert Combat.buff_active?(updated.meta.combat, "damo-qingxin")
      assert published_text(conn) =~ "浑身一麻"
    end
  end

  describe "华山剑法·剑掌五连环（攻击方）" do
    test "剑法不足被拒" do
      conn = perform([skills: %{"huashan-jian" => 49, "force" => 100}], "huashan-jian", "lian", "sword")
      assert output_text(conn) =~ "不够纯熟"
    end

    test "成功放招投递目标侧事件" do
      conn =
        perform(
          [
            skills: %{"huashan-jian" => 60, "force" => 100, "sword" => 60},
            mapped: %{"sword" => "huashan-jian"}
          ],
          "huashan-jian",
          "lian",
          "sword"
        )

      assert published_text(conn) =~ "剑掌齐发"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "huashan-jian/lian", level: 60, attacker: %{id: "player-1"}}
      }
    end
  end

  describe "华山剑法·剑掌五连环（目标侧结算）" do
    defp attacker, do: %{id: "player-1", pid: self(), name: "张三", room_id: @room}

    test "5 击命中造成伤害并回执" do
      character = build_character(skills: %{"dodge" => 0})
      data = %{perform_id: "huashan-jian/lian", level: 100, rng: fn _ -> 1 end}

      conn =
        CombatEvent.perform_incoming(build_conn(character), %{data: Map.merge(%{attacker: attacker()}, data)})

      updated = conn.private.update_character
      # rng=_->1 → Engine.rand=0：每击 level/10=10，5 击=50（失败扣血），
      # 忙乱命中 random(5)==0 → 目标忙乱 1；feedback 忙乱 1+rand(3)=1
      assert updated.meta.vitals.qi == Vitals.new().qi - 50
      assert updated.meta.combat.busy == 1
      assert published_text(conn) =~ "连中数招"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 120, busy: 1}}
    end

    test "全部落空则不扣血" do
      character = build_character(skills: %{"dodge" => 999})
      data = %{perform_id: "huashan-jian/lian", level: 100, rng: fn _ -> 1 end}

      conn =
        CombatEvent.perform_incoming(build_conn(character), %{data: Map.merge(%{attacker: attacker()}, data)})

      assert conn.private.update_character.meta.vitals.qi == Vitals.new().qi
      assert published_text(conn) =~ "左闪右避"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 120}}
    end
  end

  describe "狂风快剑·横扫乾坤（攻击方）" do
    test "剑法不足被拒" do
      conn = perform([skills: %{"kuangfeng-jian" => 99, "force" => 200}], "kuangfeng-jian", "sao", "sword")
      assert output_text(conn) =~ "火候不够"
    end

    test "成功放招投递目标侧事件（含 attack_bonus）" do
      conn =
        perform(
          [
            skills: %{"kuangfeng-jian" => 150, "force" => 200, "sword" => 150},
            mapped: %{"sword" => "kuangfeng-jian"}
          ],
          "kuangfeng-jian",
          "sao",
          "sword"
        )

      assert published_text(conn) =~ "横扫"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "kuangfeng-jian/sao", level: 150, attack_bonus: 0, attacker: %{id: "player-1"}}
      }
    end
  end

  describe "狂风快剑·横扫乾坤（目标侧结算）" do
    defp attacker, do: %{id: "player-1", pid: self(), name: "张三", room_id: @room}

    test "6 击命中造成伤害并回执" do
      character = build_character(skills: %{"dodge" => 0})
      data = %{perform_id: "kuangfeng-jian/sao", level: 120, attack_bonus: 0, rng: fn _ -> 1 end}

      conn =
        CombatEvent.perform_incoming(build_conn(character), %{data: Map.merge(%{attacker: attacker()}, data)})

      updated = conn.private.update_character
      # rng=_->1 → Engine.rand=0：每击 level/10=12，6 击=72；
      # 忙乱命中 random(2)==0 → 目标忙乱 1；feedback 忙乱 1+rand(6)=1
      assert updated.meta.vitals.qi == Vitals.new().qi - 72
      assert updated.meta.combat.busy == 1
      assert published_text(conn) =~ "毫无还手之力"
      assert_receive %Kalevala.Event{topic: "combat/perform-feedback", data: %{neili_cost: 150, busy: 1}}
    end
  end

  describe "反两仪刀法·双剑和壁（攻击方门槛）" do
    test "未入队被拒" do
      conn = perform([skills: %{"fanliangyi-dao" => 60, "force" => 50}, mapped: %{"blade" => "fanliangyi-dao"}], "fanliangyi-dao", "makearray", "blade")
      assert output_text(conn) =~ "还没有加入任何队伍"
    end

    test "队伍人数不对被拒" do
      team = %{id: "t1", leader_pid: self(), members: [%{id: "player-1", pid: self(), name: "张三"}]}
      conn =
        perform(
          [skills: %{"fanliangyi-dao" => 60, "force" => 50}, mapped: %{"blade" => "fanliangyi-dao"}, team: team],
          "fanliangyi-dao",
          "makearray",
          "blade"
        )

      assert output_text(conn) =~ "共需两人"
    end

    test "未激发反两仪刀被拒" do
      team = %{
        id: "t1",
        leader_pid: self(),
        members: [
          %{id: "player-1", pid: self(), name: "张三"},
          %{id: "mob-1", pid: self(), name: "李四"}
        ]
      }

      conn =
        perform([skills: %{"fanliangyi-dao" => 60, "force" => 50}, team: team], "fanliangyi-dao", "makearray", "blade")

      assert output_text(conn) =~ "你必须使用反两仪刀法"
    end

    test "刀法不足被拒" do
      team = team_two()
      conn =
        perform(
          [skills: %{"fanliangyi-dao" => 29, "force" => 50}, mapped: %{"blade" => "fanliangyi-dao"}, team: team],
          "fanliangyi-dao",
          "makearray",
          "blade"
        )

      assert output_text(conn) =~ "还不够熟练"
    end

    test "已组阵则拒绝" do
      character =
        fighter(
          [
            skills: %{"fanliangyi-dao" => 60, "force" => 50},
            performs: MapSet.new(["fanliangyi-dao/makearray"]),
            mapped: %{"blade" => "fanliangyi-dao"},
            vitals: @vitals,
            team: team_two()
          ],
          "blade"
        )
        |> with_buff("array/fanliangyi-dao")

      conn = PerformCommand.run(build_conn(character), %{"action" => "fanliangyi-dao.makearray"})
      assert output_text(conn) =~ "他已经在刀阵中了"
    end
  end

  describe "反两仪刀法·双剑和壁（组阵成功）" do
    test "队长侧加成 n=skill*6 并投递队友事件" do
      conn =
        perform(
          [skills: %{"fanliangyi-dao" => 60, "force" => 50}, mapped: %{"blade" => "fanliangyi-dao"}, team: team_two()],
          "fanliangyi-dao",
          "makearray",
          "blade"
        )

      updated = conn.private.update_character
      assert updated.meta.combat.temp.attack == 360
      assert updated.meta.combat.temp.defense == 360
      assert updated.meta.combat.temp.damage == 360
      assert updated.meta.combat.temp.armor == 360
      assert Combat.buff_active?(updated.meta.combat, "array/fanliangyi-dao")
      assert published_text(conn) =~ "两仪方位"

      assert_receive %Kalevala.Event{
        topic: "array/fanliangyi-dao",
        data: %{n: 360, leader: %{name: "张三"}}
      }
    end
  end

  describe "反两仪刀·队友侧事件处理" do
    defp partner(opts) do
      character = build_character(Keyword.merge(opts, team: nil))
      combat = character.meta.combat |> Combat.equip(:weapon, %{name: "刀", skill_type: "blade"})
      %{character | meta: %{character.meta | combat: combat}}
    end

    test "门槛通过：加成 n 并挂阵 buff" do
      character =
        partner(
          skills: %{"fanliangyi-dao" => 60, "force" => 50},
          mapped: %{"blade" => "fanliangyi-dao"}
        )

      conn =
        FanliangyiEvent.array(build_conn(character), %{data: %{leader: %{name: "张三"}, n: 360}})

      updated = conn.private.update_character
      assert updated.meta.combat.temp.attack == 360
      assert updated.meta.combat.temp.defense == 360
      assert updated.meta.combat.temp.damage == 360
      assert updated.meta.combat.temp.armor == 360
      assert Combat.buff_active?(updated.meta.combat, "array/fanliangyi-dao")
      assert output_text(conn) =~ "反两仪刀阵"
    end

    test "门槛不过（不会刀法）：静默忽略" do
      character = partner(skills: %{"force" => 50})
      conn = FanliangyiEvent.array(build_conn(character), %{data: %{leader: %{name: "张三"}, n: 360}})
      assert conn.private.update_character == nil
      assert output_text(conn) == ""
    end
  end

  defp team_two() do
    %{
      id: "t1",
      leader_pid: self(),
      members: [
        %{id: "player-1", pid: self(), name: "张三"},
        %{id: "mob-1", pid: self(), name: "李四"}
      ]
    }
  end
end