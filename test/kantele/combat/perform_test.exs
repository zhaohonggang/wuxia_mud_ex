defmodule Kantele.Combat.PerformExertTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.ExertCommand
  alias Kantele.Character.PerformCommand
  alias Kantele.Character.SkillsEvent
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @vitals Vitals.new()

  defp build_character(stats_overrides \\ %{}) do
    stats = struct(Stats.new(), stats_overrides)

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "liuxi:lianwuchang",
      meta: %Kantele.Character.PlayerMeta{
        vitals: @vitals,
        stats: stats,
        combat: Combat.new()
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp conn_for(character) do
    build_conn(character)
  end

  # Broadcast.publish 走房间频道（运行时由频道回声渲染），测试从 channel_changes 提取
  defp published_text(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn change ->
      match?({:publish, _, %Kalevala.Event{topic: Kalevala.Event.Message}, _, _}, change)
    end)
    |> Enum.map(fn {:publish, _channel, event, _opts, _error} -> event.data.text end)
    |> Enum.join("")
  end

  describe "perform liuxin-jian.liu（柳浪闻莺）" do
    test "未学会时拒绝" do
      character = build_character(skills: %{"liuxin-jian" => 70, "force" => 30})

      conn =
        PerformCommand.run(conn_for(character), %{
          "action" => "liuxin-jian.liu",
          "command" => "perform"
        })

      assert output_text(conn) =~ "你还没有学过这一招"
    end

    test "等级不足时拒绝" do
      character =
        build_character(
          skills: %{"liuxin-jian" => 50, "force" => 30},
          performs: MapSet.new(["liuxin-jian/liu"])
        )

      conn =
        PerformCommand.run(conn_for(character), %{
          "action" => "liuxin-jian.liu",
          "command" => "perform"
        })

      assert output_text(conn) =~ "不够娴熟"
    end

    test "内力不足时拒绝" do
      character =
        build_character(
          skills: %{"liuxin-jian" => 70, "force" => 30},
          performs: MapSet.new(["liuxin-jian/liu"])
        )

      character = put_in(character.meta.vitals.neili, 50)

      conn =
        PerformCommand.run(conn_for(character), %{
          "action" => "liuxin-jian.liu",
          "command" => "perform"
        })

      assert output_text(conn) =~ "内力不够"
    end

    test "成功施展：扣内力、apply/dodge 提升、定时消退事件入队" do
      character =
        build_character(
          skills: %{"liuxin-jian" => 72, "force" => 30},
          performs: MapSet.new(["liuxin-jian/liu"])
        )

      conn =
        PerformCommand.run(conn_for(character), %{
          "action" => "liuxin-jian.liu",
          "command" => "perform"
        })

      updated = conn.private.update_character

      # skill/4 = 18, skill/5 = 14
      assert updated.meta.combat.temp.dodge == 18
      assert updated.meta.combat.temp.attack == 14
      assert updated.meta.vitals.neili == @vitals.neili - 80
      assert Combat.buff_active?(updated.meta.combat, "liuxin-liu")

      # 定时消退经 Process.send_after 自投递（时长见下方注释），e2e 覆盖实际到期

      assert published_text(conn) =~ "张三长吟一声"
      assert published_text(conn) =~ "剑尖颤出万千朵浪花"
    end

    test "重复施展被拒绝" do
      character =
        build_character(
          skills: %{"liuxin-jian" => 72, "force" => 30},
          performs: MapSet.new(["liuxin-jian/liu"])
        )

      combat = Combat.add_buff(Combat.new(), %Buff{key: "liuxin-liu", applies: %{}})
      character = put_in(character.meta.combat, combat)

      conn =
        PerformCommand.run(conn_for(character), %{
          "action" => "liuxin-jian.liu",
          "command" => "perform"
        })

      assert output_text(conn) =~ "竭尽全力"
    end

    test "buff 到期回收加成并提示" do
      combat =
        Combat.new()
        |> Combat.apply_temp(%{dodge: 18, attack: 14})
        |> Combat.add_buff(%Buff{key: "liuxin-liu", applies: %{dodge: -18, attack: -14}})

      character = build_character()
      character = put_in(character.meta.combat, combat)

      conn =
        Kantele.Character.CombatEvent.buff_expire(conn_for(character), %{
          topic: "combat/buff-expire",
          data: %{key: "liuxin-liu", applies: %{dodge: -18, attack: -14}, message: "余韵散去\n"}
        })

      updated = conn.private.update_character

      assert updated.meta.combat.temp.dodge == 0
      assert updated.meta.combat.temp.attack == 0
      refute Combat.buff_active?(updated.meta.combat, "liuxin-liu")
      assert output_text(conn) =~ "余韵散去"
    end
  end

  describe "exert powerup（柳溪内功）" do
    test "未映射内功时拒绝" do
      character = build_character()

      conn =
        ExertCommand.run(conn_for(character), %{"function" => "powerup", "command" => "exert"})

      assert output_text(conn) =~ "你不会这种运功方法"
    end

    test "真气不足时拒绝" do
      character =
        build_character(
          skills: %{"force" => 90},
          mapped: %{"force" => "liuxi-neigong"}
        )

      character = put_in(character.meta.vitals.neili, 50)

      conn =
        ExertCommand.run(conn_for(character), %{"function" => "powerup", "command" => "exert"})

      assert output_text(conn) =~ "真气不够"
    end

    test "成功运功：攻防各提升 force/3，战斗中 busy，定时消退" do
      character =
        build_character(
          skills: %{"force" => 90, "liuxi-neigong" => 90},
          mapped: %{"force" => "liuxi-neigong"}
        )

      {combat, _new?} =
        Combat.add_enemy(character.meta.combat, %{id: "npc:1", pid: self(), name: "野猪"})

      character = put_in(character.meta.combat, combat)

      conn =
        ExertCommand.run(conn_for(character), %{"function" => "powerup", "command" => "exert"})

      updated = conn.private.update_character

      assert updated.meta.combat.temp.attack == 30
      assert updated.meta.combat.temp.defense == 30
      assert updated.meta.vitals.neili == @vitals.neili - 100
      assert updated.meta.combat.busy > 0
      assert Combat.buff_active?(updated.meta.combat, "powerup")

      # 定时自投递（force 秒后到期，e2e/手测覆盖）

      assert published_text(conn) =~ "运起柳溪内功"
    end
  end

  describe "learn 授艺回执" do
    test "learn_result 提升等级并在 60 层解锁绝招" do
      character = build_character(skills: %{"sword" => 70, "force" => 30, "liuxin-jian" => 59})

      conn =
        SkillsEvent.learn_result(conn_for(character), %{
          topic: "skills/learn-result",
          from_pid: self(),
          data: %{skill: "liuxin-jian"}
        })

      updated = conn.private.update_character

      assert Stats.skill(updated.meta.stats, "liuxin-jian") == 60
      assert Stats.perform_known?(updated.meta.stats, "liuxin-jian/liu")
      assert output_text(conn) =~ "柳浪闻莺"
    end

    test "师父回绝时不改动属性" do
      character = build_character()

      conn =
        SkillsEvent.learn_result(conn_for(character), %{
          topic: "skills/learn-result",
          from_pid: self(),
          data: %{skill: nil, failure_message: "老夫不会。\n"}
        })

      assert is_nil(conn.private.update_character)
      assert output_text(conn) =~ "老夫不会"
    end
  end
end
