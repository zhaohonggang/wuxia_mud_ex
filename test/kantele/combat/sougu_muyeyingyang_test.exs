defmodule Kantele.Combat.SouguMuyeyingyangTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.PerformCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills.Performs.Sougu.Muyeyingyang

  @room "sougu:yard"

  # neili 充足（>=800），str 默认 20 需上调
  defp base_vitals, do: %{Vitals.new() | neili: 900, max_neili: 900}

  defp build_character(opts) do
    stats = struct(Stats.new(), Keyword.take(opts, [:skills, :mapped, :performs, :str, :combat_exp]))

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: @room,
      meta: %Kantele.Character.PlayerMeta{
        vitals: Keyword.get(opts, :vitals, base_vitals()),
        stats: stats,
        combat: Keyword.get(opts, :combat, Combat.new())
      }
    }
  end

  defp enemy, do: %{id: "mob-1", pid: self(), name: "恶犬", room_id: @room}

  defp performer(opts) do
    character = build_character(opts)
    combat = %{character.meta.combat | enemies: [enemy()]}
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
      {:publish, _channel, %Kalevala.Event{topic: Kalevala.Event.Message, data: data}, _, _} ->
        [data.text]

      _ ->
        []
    end)
    |> Enum.join("")
  end

  @ok_skills %{"sougu" => 150}

  defp perform(opts) do
    opts =
      opts
      |> Keyword.put_new(:str, 30)
      |> Keyword.put_new(:skills, @ok_skills)
      |> Keyword.put_new(:performs, MapSet.new(["sougu/muyeyingyang"]))

    PerformCommand.run(build_conn(performer(opts)), %{"action" => "sougu.muyeyingyang"})
  end

  describe "牧野鹰扬（攻击方门槛，逐条对照 muyeyingyang.c）" do
    test "未学会被拒（你所使用的外功中没有这种功能）" do
      conn = perform(performs: MapSet.new(), skills: @ok_skills)
      assert output_text(conn) =~ "外功中没有这种功能"
    end

    test "无战斗目标被拒（牧野鹰扬只能对战斗中的对手使用）" do
      character = build_character(str: 30, skills: @ok_skills, performs: MapSet.new(["sougu/muyeyingyang"]))

      conn =
        PerformCommand.run(build_conn(character), %{"action" => "sougu.muyeyingyang"})

      assert output_text(conn) =~ "牧野鹰扬只能对战斗中的对手使用"
    end

    test "臂力不足被拒（query_str() < 30）" do
      conn = perform(str: 29)
      assert output_text(conn) =~ "你臂力不够,不能使用牧野鹰扬！"
    end

    test "等级不足被拒（query_skill(\"sougu\") < 150）" do
      conn = perform(skills: %{"sougu" => 149})
      assert output_text(conn) =~ "你的搜骨鹰爪功修为不够,目前还不能使用牧野鹰扬！"
    end

    test "内力不足被拒（query(\"neili\") < 800）" do
      conn = perform(vitals: %{base_vitals() | neili: 799})
      assert output_text(conn) =~ "你内力现在不够, 不能使用牧野鹰扬！"
    end

    test "门槛满足：广播起手式并投递目标侧事件（带 combat_exp）" do
      conn = perform([])

      assert published_text(conn) =~ "使出搜骨鹰爪功绝技「牧野鹰扬」，双爪蓦地抓向"

      assert_receive %Kalevala.Event{
        topic: "combat/perform-incoming",
        data: %{perform_id: "sougu/muyeyingyang", level: 150, attacker: %{id: "player-1"}}
      }
    end
  end

  describe "牧野鹰扬（目标侧结算）" do
    defp attacker, do: %{id: "player-1", pid: self(), name: "张三", room_id: @room}

    defp incoming(character, data) do
      CombatEvent.perform_incoming(build_conn(character), %{
        data: Map.merge(%{attacker: attacker(), perform_id: "sougu/muyeyingyang"}, data)
      })
    end

    test "目标忙乱：直接回执文案，不结算" do
      combat = %{Combat.new() | busy: 5}
      character = build_character(combat: combat, combat_exp: 1000)

      conn = incoming(character, %{level: 150, combat_exp: 1000, rng: fn _ -> 1 end})

      assert published_text(conn) =~ "目前正自顾不暇，放胆攻击吧"
      refute conn.private.update_character
    end

    # 说明：框架 `CombatEvent.perform_incoming/2` 会在调 `resolve_incoming` 前
    # 先 `dead?(character) -> conn` 短路（与 LPC 的 `! living(target)` 语义等价的
    # 兜底）。因此本模块 `resolve_incoming/4` 内的 `combat.dead` 分支只能直接调用
    # 才会走到，这里直接调 `Muyeyingyang.resolve_incoming/4` 验证该分支文案。
    test "目标已死：living 门槛文案（直接调 resolve_incoming，绕过框架短路）" do
      combat = %{Combat.new() | dead: true}
      character = build_character(combat: combat, combat_exp: 1000)

      conn =
        Muyeyingyang.resolve_incoming(
          build_conn(character),
          character,
          attacker(),
          %{level: 150, combat_exp: 1000, rng: fn _ -> 1 end}
        )

      assert published_text(conn) =~ "对方都已经这样了，用不着这么费力吧"
      refute conn.private.update_character
    end

    test "目标已死：框架层直接短路（perform_incoming 不发任何文案）" do
      combat = %{Combat.new() | dead: true}
      character = build_character(combat: combat, combat_exp: 1000)

      conn = incoming(character, %{level: 150, combat_exp: 1000, rng: fn _ -> 1 end})

      assert published_text(conn) == ""
      refute conn.private.update_character
    end

    test "命中：目标忙乱 sougu/22+1，攻击方回执 -150/0" do
      # ob_exp=1000 → 阈值 500；rand=600 > 500 命中
      character = build_character(combat_exp: 1000)

      conn = incoming(character, %{level: 150, combat_exp: 1000, rng: fn _ -> 600 end})

      assert published_text(conn) =~ "立时动弹不得"

      # 150 / 22 + 1 = 7
      assert conn.private.update_character.meta.combat.busy == 7

      assert_receive %Kalevala.Event{
        topic: "combat/perform-feedback",
        data: %{neili_cost: 150, busy: 0}
      }
    end

    test "未中：攻击方忙乱 4，不消耗内力" do
      # ob_exp=1000 → 阈值 500；rand=1 未命中
      character = build_character(combat_exp: 1000)

      conn = incoming(character, %{level: 150, combat_exp: 1000, rng: fn _ -> 1 end})

      assert published_text(conn) =~ "并没有上当"

      refute conn.private.update_character

      assert_receive %Kalevala.Event{
        topic: "combat/perform-feedback",
        data: %{neili_cost: 0, busy: 4}
      }
    end
  end
end
