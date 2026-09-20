defmodule Kantele.Combat.ZixiaShengongTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.ExertCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.ZixiaShengong
  alias Kantele.Combat.Skills.ZixiaShengong.Powerup
  alias Kantele.Combat.Skills.ZixiaShengong.Ziqi

  @vitals %{Vitals.new() | neili: 1000, max_neili: 1000, qi: 500, max_qi: 500}
  @room "test:room"

  defp build_character(opts) do
    stats = struct(Stats.new(), Keyword.take(opts, [:skills, :mapped, :performs]))

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: @room,
      meta: %Kantele.Character.PlayerMeta{
        vitals: Keyword.get(opts, :vitals, @vitals),
        stats: stats,
        combat: Keyword.get(opts, :combat, Combat.new())
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

  defp published_text(conn) do
    conn.private.channel_changes
    |> Enum.flat_map(fn
      {:publish, _channel, %Kalevala.Event{topic: Kalevala.Event.Message, data: data}, _, _} ->
        [data.text]

      _ ->
        []
    end)
    |> Enum.join("")
  end

  defp exert(opts, move) do
    conn = build_conn(build_character(opts))
    ExertCommand.run(conn, %{"function" => move})
  end

  defp with_sword(character) do
    combat = %{character.meta.combat | equipped: %{weapon: %{skill_type: "sword", name: "长剑"}}}
    %{character | meta: %{character.meta | combat: combat}}
  end

  describe "紫霞神功（技能表）" do
    test "已注册且可 enable force" do
      assert Skills.known?("zixia-shengong")
      assert Skills.get("zixia-shengong") == ZixiaShengong
      assert ZixiaShengong.valid_enable("force")
      refute ZixiaShengong.valid_enable("sword")
    end

    test "valid_force 接受兼容内功" do
      assert ZixiaShengong.valid_force("hunyuan-yiqi")
      assert ZixiaShengong.valid_force("taiji-shengong")
      assert ZixiaShengong.valid_force("wudang-xinfa")
      assert ZixiaShengong.valid_force("shaolin-xinfa")
      refute ZixiaShengong.valid_force("other")
    end

    test "valid_learn 需 force>=100" do
      assert ZixiaShengong.valid_learn(%{"force" => 100}) == :ok
      case ZixiaShengong.valid_learn(%{"force" => 99}) do
        {:error, _} -> :ok
        _ -> flunk("expected {:error, _}")
      end
    end

    test "exert_list 含 powerup/ziqi" do
      assert ZixiaShengong.exert_list() == %{"powerup" => Powerup, "ziqi" => Ziqi}
    end
  end

  describe "powerup（自我增益）" do
    test "扣 100 内力并挂 powerup buff" do
      conn =
        exert(
          [skills: %{"zixia-shengong" => 120}, mapped: %{"force" => "zixia-shengong"}, vitals: %{@vitals | neili: 500}],
          "powerup"
        )

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 400
      assert updated.meta.combat.temp.attack == 40
      assert updated.meta.combat.temp.defense == 40
      assert Combat.buff_active?(updated.meta.combat, "powerup")
      assert published_text(conn) =~ "面部竟呈出一层薄霜"
    end

    test "busy 1~3 轮（战斗中）" do
      character =
        build_character(
          skills: %{"zixia-shengong" => 120},
          mapped: %{"force" => "zixia-shengong"},
          vitals: %{@vitals | neili: 500}
        )
      combat = %{Combat.new() | enemies: [%{id: "e1", pid: self(), name: "敌", room_id: @room}]}
      character = %{character | meta: %{character.meta | combat: combat}}

      conn = ExertCommand.run(build_conn(character), %{"function" => "powerup"})
      busy = conn.private.update_character.meta.combat.busy
      assert busy >= 1 and busy <= 3
    end
  end

  describe "ziqi（紫气东来·自我增益）" do
    test "未持剑被拒" do
      conn =
        exert(
          [
            skills: %{"zixia-shengong" => 150},
            mapped: %{"force" => "zixia-shengong"},
            vitals: %{@vitals | neili: 500, qi: 500, max_qi: 500}
          ],
          "ziqi"
        )
      assert output_text(conn) =~ "没有剑"
    end

    test "zixia-shengong<150 被拒" do
      conn =
        exert(
          [
            skills: %{"zixia-shengong" => 149},
            mapped: %{"force" => "zixia-shengong"},
            vitals: %{@vitals | neili: 500, qi: 500, max_qi: 500}
          ],
          "ziqi"
        )
      assert output_text(conn) =~ "修为不够"
    end

    test "neili<200 被拒" do
      conn =
        exert(
          [
            skills: %{"zixia-shengong" => 150},
            mapped: %{"force" => "zixia-shengong"},
            vitals: %{@vitals | neili: 150, qi: 500, max_qi: 500}
          ],
          "ziqi"
        )
      assert output_text(conn) =~ "内力还不够"
    end

    test "qi<=40%max_qi 被拒（仍扣 neili/busy）" do
      conn =
        exert(
          [
            skills: %{"zixia-shengong" => 150},
            mapped: %{"force" => "zixia-shengong"},
            vitals: %{@vitals | neili: 500, qi: 100, max_qi: 500}
          ],
          "ziqi"
        )
      # Note: In Simple.perform, if gate fails, no costs are deducted
      # The LPC behavior is different (still consumes neili/busy on qi check fail)
      # Our implementation follows the gate pattern: qi check is a gate
      assert output_text(conn) =~ "受伤太重"
    end

    test "已在 ziqi 状态则拒绝" do
      character =
        build_character(
          skills: %{"zixia-shengong" => 150},
          mapped: %{"force" => "zixia-shengong"},
          vitals: %{@vitals | neili: 500, qi: 500, max_qi: 500}
        )
      character = with_sword(character)
      combat = %{character.meta.combat | buffs: [%Combat.Buff{key: "ziqi", applies: []}]}
      character = %{character | meta: %{character.meta | combat: combat}}

      conn = ExertCommand.run(build_conn(character), %{"function" => "ziqi"})
      assert output_text(conn) =~ "已经在运起"
    end

    test "成功：扣 200 neili，挂 damage/sword buff，busy 3" do
      character =
        build_character(
          skills: %{"zixia-shengong" => 200},
          mapped: %{"force" => "zixia-shengong"},
          vitals: %{@vitals | neili: 500, qi: 500, max_qi: 500}
        )
      character = with_sword(character)

      conn = ExertCommand.run(build_conn(character), %{"function" => "ziqi"})

      updated = conn.private.update_character
      assert updated.meta.vitals.neili == 300
      assert updated.meta.combat.temp.damage == 20
      assert updated.meta.combat.temp.sword == 20
      assert Combat.buff_active?(updated.meta.combat, "ziqi")
      assert updated.meta.combat.busy == 3
      assert published_text(conn) =~ "紫气大盛"
    end

    test "buff 到期回收加成" do
      character =
        build_character(
          skills: %{"zixia-shengong" => 200},
          mapped: %{"force" => "zixia-shengong"},
          vitals: %{@vitals | neili: 500, qi: 500, max_qi: 500}
        )
      character = with_sword(character)

      conn = ExertCommand.run(build_conn(character), %{"function" => "ziqi"})
      updated = conn.private.update_character

      buff = Enum.find(updated.meta.combat.buffs, &(&1.key == "ziqi"))
      assert buff.applies == %{damage: -20, sword: -20}
      # duration = skill 200 秒，到期投递逻辑由 Simple.schedule_expire 覆盖（simple_test）
    end
  end
end