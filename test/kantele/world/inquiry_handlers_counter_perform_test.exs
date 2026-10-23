defmodule Kantele.World.InquiryHandlers.CounterPerformTest do
  @moduledoc """
  P5-4ar：计数器式渐进授绝招（`kind = "counter_perform"`），镜像
  `kungfu/class/wudang/zhang.c` `ask_skill6`（张三丰「太极图」）。

  覆盖：计数器封顶 / 门派 / 必修技能 / 贡献 / 杀气 / 各技能等级（独立文案）/
  精力 / 潜能 / 计数递增 / 第 10 次学会绝招并扣贡献。
  """
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kantele.Character.NpcScriptEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @counter_key "can_perform/taiji-quan/tu"
  @room "test:room"

  # 真实数据校验：整库加载一次（~15s，clone_fallback_test 同成本），验证
  # wudang.ucl 的太极图 inquiry 端到端解析为 counter_perform 管道。
  setup_all do
    %{world: Kantele.World.Loader.load()}
  end

  defp config(overrides \\ %{}) do
    Map.merge(
      %{
        "kind" => "counter_perform",
        "perform_id" => "taiji-quan/tu",
        "skill" => "taiji-quan",
        "counter_key" => @counter_key,
        "max_count" => 10,
        "family" => "武当派",
        "min_levels" => %{"taiji-quan" => 250, "taiji-shengong" => 300, "taoism" => 300},
        "level_deny" => %{
          "taiji-quan" => "你的太极拳法还不到家，要多练练！",
          "taiji-shengong" => "你的太极神功还不到家，好好修行吧！",
          "taoism" => "你的道学心法研究的还不够明白，要下功夫苦学才是！"
        },
        "min_gongxian" => 3000,
        "min_shen" => 250_000,
        "max_jingli" => 1000,
        "potential_cost" => 100,
        "cost_gongxian" => 3000,
        "improve_skills" => %{"taiji-shengong" => 3, "taoism" => 3, "martial-cognize" => 1}
      },
      overrides
    )
  end

  # 全门槛达标的武当弟子（精力/潜能也够）
  defp qualified(overrides \\ []) do
    stats = %Stats{
      skills: %{
        "taiji-quan" => 300,
        "taiji-shengong" => 320,
        "taoism" => 310,
        "force" => 400,
        "unarmed" => 400,
        "martial-cognize" => 400
      },
      gongxian: 5000,
      shen: 300_000,
      potential: 1000,
      learned_points: 0,
      performs: MapSet.new()
    }

    player(Keyword.merge([stats: stats, family: %{name: "武当派"}, jingli: 2000], overrides))
  end

  # opts[:stats] 既可是部分 map（与 Stats.new() 合并），也可是完整 %Stats{}
  defp player(opts) do
    stats =
      case Keyword.get(opts, :stats, %{}) do
        %Stats{} = full -> full
        partial when is_map(partial) -> struct(Stats.new(), partial)
      end

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: @room,
      meta: %PlayerMeta{
        vitals: %Vitals{Vitals.new() | max_jingli: Keyword.get(opts, :jingli, 0)},
        stats: stats,
        combat: Kantele.Character.Combat.new(),
        family: Keyword.get(opts, :family),
        marks: Keyword.get(opts, :marks, %{})
      }
    }
  end

  defp inquiry_event(config, opts) do
    %Event{
      topic: "npc/inquiry",
      from_pid: self(),
      data: %{
        kind: "counter_perform",
        config: config,
        npc_name: "张三丰",
        npc_pid: self(),
        npc_room_id: @room,
        asker_id: "player-1",
        asker_name: "张三",
        remaining: :infinity
      }
      |> Map.merge(Map.new(opts))
    }
  end

  defp run(character, config \\ config(), opts \\ []) do
    NpcScriptEvent.inquiry_result(build_conn(character), inquiry_event(config, opts))
  end

  defp updated(conn), do: conn.private.update_character || conn.character

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp counter_of(character), do: PlayerMeta.mark(character.meta, @counter_key) || 0

  describe "门控（顺序 = LPC ask_skill6）" do
    test "计数器已封顶（10）→ 该学的你都已经学了" do
      character = qualified(marks: %{@counter_key => 10})
      conn = run(character)
      assert output_text(conn) =~ "该学的你都已经学了"
      assert conn.private.update_character == nil
    end

    test "非武当派 → 敬称 + 不是我们武当派的人" do
      character = qualified(family: %{name: "少林派"})
      conn = run(character)
      assert output_text(conn) =~ "不是我们武当派的人"
      assert conn.private.update_character == nil
    end

    test "没学太极拳 → 你连太极拳都没学" do
      stats = %Stats{skills: %{"force" => 400}, gongxian: 5000, shen: 300_000, potential: 1000}
      conn = run(player(stats: stats, family: %{name: "武当派"}, jingli: 2000))
      assert output_text(conn) =~ "你连太极拳都没学"
      assert conn.private.update_character == nil
    end

    test "贡献不足 → 效力还不够" do
      stats = %Stats{
        skills: %{"taiji-quan" => 300, "taiji-shengong" => 320, "taoism" => 310},
        gongxian: 100,
        shen: 300_000,
        potential: 1000
      }

      conn = run(player(stats: stats, family: %{name: "武当派"}, jingli: 2000))
      assert output_text(conn) =~ "你为我武当派效力还不够"
      assert conn.private.update_character == nil
    end

    test "杀气不足 → 行侠仗义做得还不够多" do
      stats = %Stats{
        skills: %{"taiji-quan" => 300, "taiji-shengong" => 320, "taoism" => 310},
        gongxian: 5000,
        shen: 1000,
        potential: 1000
      }

      conn = run(player(stats: stats, family: %{name: "武当派"}, jingli: 2000))
      assert output_text(conn) =~ "行侠仗义的事情做得还不够多"
      assert conn.private.update_character == nil
    end

    test "技能等级不够 → 各技能独立文案（太极神功）" do
      stats = %Stats{
        skills: %{"taiji-quan" => 300, "taiji-shengong" => 100, "taoism" => 310},
        gongxian: 5000,
        shen: 300_000,
        potential: 1000
      }

      conn = run(player(stats: stats, family: %{name: "武当派"}, jingli: 2000))
      assert output_text(conn) =~ "你的太极神功还不到家"
      assert conn.private.update_character == nil
    end

    test "精力不济 → 难以运用" do
      conn = run(qualified(jingli: 500))
      assert output_text(conn) =~ "你的精力不济"
      assert conn.private.update_character == nil
    end

    test "潜能不够 → 没有研究出什么新的东西" do
      stats = %Stats{
        skills: %{"taiji-quan" => 300, "taiji-shengong" => 320, "taoism" => 310},
        gongxian: 5000,
        shen: 300_000,
        potential: 50,
        learned_points: 0
      }

      conn = run(player(stats: stats, family: %{name: "武当派"}, jingli: 2000))
      assert output_text(conn) =~ "看来是潜能还不够"
      # 潜能门控在广播之后，未落库
      assert conn.private.update_character == nil
    end

    test "它人事件不处理" do
      conn = run(qualified(), config(), asker_id: "someone")
      assert conn.private.update_character == nil
      assert output_text(conn) == ""
    end
  end

  describe "授业与计数" do
    test "全门槛达标 → 计数 +1、learned_points +100、私发领悟 + 房间广播" do
      conn = run(qualified())

      character = updated(conn)
      assert counter_of(character) == 1
      assert character.meta.stats.learned_points == 100
      assert output_text(conn) =~ "你对太极图有了一点领悟"
      # 未学会绝招
      refute Stats.perform_known?(character.meta.stats, "taiji-quan/tu")

      # 房间广播：张三丰划圈 + NPC 发言「你看懂了多少？」+ 玩家沉思
      publishes =
        Enum.filter(conn.private.channel_changes, fn
          {:publish, "rooms:#{@room}", _, _, _} -> true
          _ -> false
        end)
        |> Enum.map(fn {:publish, _c, event, _o, _f} -> event.data.text end)

      assert length(publishes) == 3
      assert Enum.any?(publishes, &String.contains?(&1, "划了一个圈子"))
      assert Enum.any?(publishes, &String.contains?(&1, "你看懂了多少？"))
      assert Enum.any?(publishes, &String.contains?(&1, "深思良久"))
    end

    test "计数从 5 继续递增（读 meta.marks）" do
      character = qualified(marks: %{@counter_key => 5})
      conn = run(character)
      assert counter_of(updated(conn)) == 6
      assert updated(conn).meta.stats.learned_points == 100
    end

    test "第 9 次仍是领悟，第 10 次学会绝招" do
      character = qualified(marks: %{@counter_key => 9})
      conn = run(character)

      character = updated(conn)
      assert counter_of(character) == 10
      assert Stats.perform_known?(character.meta.stats, "taiji-quan/tu")

      assert output_text(conn) =~ "你学会了道家密技「太极图」"
      # 完成时扣贡献 3000（5000 - 3000）
      assert character.meta.stats.gongxian == 2000
      # improve_skills 按次数 +N
      assert character.meta.stats.skills["taoism"] == 313
      assert character.meta.stats.skills["martial-cognize"] == 401
    end

    test "无 npc_room_id 时不广播（仅私发）" do
      conn = run(qualified(), config(), npc_room_id: nil)

      publishes =
        Enum.filter(conn.private.channel_changes, fn
          {:publish, "rooms:" <> _, _, _, _} -> true
          _ -> false
        end)

      assert publishes == []
      assert output_text(conn) =~ "你对太极图有了一点领悟"
    end
  end

  describe "真实数据（wudang.ucl 张三丰）" do
    test "太极图 inquiry 走 counter_perform 管道且门控字段齐全", %{world: world} do
      # 角色 id 是加载时生成的哈希，按名字 + 房间定位张三丰（wudang:xiaoyuan）
      npc =
        Enum.find(world.characters, fn c ->
          c.name == "张三丰" and c.room_id == "wudang:xiaoyuan"
        end)

      assert npc, "张三丰应随世界加载（wudang:xiaoyuan）"

      inquiry = npc.meta.inquiries["太极图"]
      assert inquiry, "张三丰应能回答「太极图」"

      assert inquiry["kind"] == "counter_perform"
      assert inquiry["perform_id"] == "taiji-quan/tu"
      assert inquiry["counter_key"] == "can_perform/taiji-quan/tu"
      assert inquiry["max_count"] == 10
      assert inquiry["family"] == "武当派"
      assert inquiry["min_gongxian"] == 3000
      assert inquiry["min_shen"] == 250_000
      assert inquiry["max_jingli"] == 1000
      assert inquiry["potential_cost"] == 100
      assert inquiry["cost_gongxian"] == 3000
      # loader 归一后的技能门槛（下划线→连字符）
      assert inquiry["min_levels"] == %{"taiji-quan" => 250, "taiji-shengong" => 300, "taoism" => 300}
      assert inquiry["level_deny"]["taiji-quan"] == "你的太极拳法还不到家，要多练练！"

      # 同 NPC 其余绝招仍走 perform_id 布尔管道（未被误改）
      assert npc.meta.inquiries["鹤嘴劲"]["perform_id"] == "taiji-shengong/dian"
      refute Map.has_key?(npc.meta.inquiries["鹤嘴劲"], "kind")
    end

    test "InquiryHandlers 注册了 counter_perform" do
      assert Kantele.World.InquiryHandlers.lookup("counter_perform") ==
               Kantele.World.InquiryHandlers.CounterPerform
    end
  end
end
