defmodule Kantele.World.XiaoyaoPassZhenlongTest do
  @moduledoc """
  逍遥派 #808：无崖子珍珓 `pass_zhenlong` 收徒分支定向测试。

  LPC 依据：`kungfu/class/xiaoyao/wuyazi.c:143-180` attempt_apprentice pass_zhenlong 分支。

  测试覆盖：
  - 无崖子 + temp["pass_zhenlong"] 时，优先于 recruit_gate?/3 触发
  - betrayer/times > 0：叹息+告白拒绝，不进入常规门控
  - betrayer/times == 0：set("betryer/times", btimes)，max_neili<500 时传功+技能提升+vision 广播
  - max_neili >= 500 时不传功，直接进入常规门控
  - 非无崖子或无 temp 标记时，不触发珍珓分支，走常规门控
  """

  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kantele.Character.FamilyEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  # 无崖子常规收徒配置（与 data/world/clone_lib.ucl apprentice 段对齐）
  defp wuyazi_apprentice do
    %{
      family: "逍遥派",
      permit_recruit: true,
      gate_order: "lpc_wuyazi",
      min_per: 28,
      any_min_skills: %{
        "xiaoyao-xinfa" => 130,
        "xiaowuxiang" => 130,
        "beiming-shengong" => 130
      },
      min_skills: %{"force" => 130, "dodge" => 130},
      hard_min_int: 40,
      min_exp: 500_000,
      accept_msg: "想不到在这世上竟然还有人可以继承我逍遥派的衣钵！\n"
    }
  end

  # 玩家侧 event data（NpcFamilyEvent.apprentice 回执）
  defp recruit_data(overrides \\ %{}) do
    overrides = Map.new(overrides)
    %{
      ok: true,
      family: "逍遥派",
      master_id: "npc:wuyazi",
      master_name: "无崖子",
      student_name: "测试玩家",
      teach: %{family: "逍遥派"},
      apprentice: wuyazi_apprentice()
    }
    |> Map.merge(overrides)
  end

  defp default_stats do
    %Stats{
      skills: %{"xiaoyao-xinfa" => 150, "force" => 150, "dodge" => 150},
      int: 45,
      per: 30,
      combat_exp: 600_000,
      shen: 0
    }
  end

  # 构造带指定覆盖的玩家
  defp build_player(overrides) do
    overrides = Map.new(overrides)
    stats = Map.merge(default_stats(), Map.get(overrides, :stats, %{}))

    vitals = %Vitals{max_neili: Map.get(overrides, :max_neili, 600)}
    env = Map.get(overrides, :env, %{gender: "男性"})
    temp = Map.get(overrides, :temp, %{})

    %Kalevala.Character{
      id: "player:test",
      name: "测试玩家",
      pid: self(),
      room_id: "xiaoyao:shishi",
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        env: env,
        temp: temp
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.map(fn
      %Kalevala.Character.Conn.Text{data: data} -> data
      _ -> ""
    end)
    |> Enum.join("")
  end

  defp vision_text(conn) do
    conn.private.channel_changes
    |> Enum.map(fn
      {:publish, _channel, %Event{data: %{text: text}}, _opts, _error_fun} ->
        text
      _ ->
        ""
    end)
    |> Enum.join("")
  end

  describe "pass_zhenlong 拦截点" do
    test "无崖子 + temp[pass_zhenlong] → 进入珍珓分支（不直接走 recruit_gate?）" do
      player = build_player(temp: %{"pass_zhenlong" => true})
      conn = build_conn(player)

      result = FamilyEvent.result(
        conn,
        %Event{topic: "family/result", data: recruit_data()}
      )

      # 珍珓分支中 max_neili=600 >= 500，不传功；常规门控达标 → :ok → accept
      assert result.private.update_character != nil
      enrolled = result.private.update_character || result.character
      assert enrolled.meta.family.name == "逍遥派"
      assert Map.get(enrolled.meta.temp, "pass_zhenlong") == nil
      # betryer/times 被记录（值为 0，typo 键保留）
      assert Map.get(enrolled.meta.env, "betryer") == %{times: 0}
      assert output_text(result) =~ "想不到在这世上竟然还有人可以继承我逍遥派的衣钵"
    end

    test "非无崖子 NPC → 不触发珍珓分支，走常规门控" do
      player = build_player(temp: %{"pass_zhenlong" => true})
      conn = build_conn(player)

      data = recruit_data(master_name: "张三丰")

      result = FamilyEvent.result(
        conn,
        %Event{topic: "family/result", data: data}
      )

      # 常规门控达标 → 收徒成功，temp 保留（未被删除）
      assert result.private.update_character != nil
      enrolled = result.private.update_character || result.character
      assert Map.get(enrolled.meta.temp, "pass_zhenlong") == true
    end

    test "无崖子 + 无 temp[pass_zhenlong] → 不触发珍珓分支，走常规门控" do
      player = build_player(temp: %{})
      conn = build_conn(player)

      result = FamilyEvent.result(
        conn,
        %Event{topic: "family/result", data: recruit_data()}
      )

      # 常规门控达标 → 收徒成功
      assert result.private.update_character != nil
    end
  end

  describe "betrayer/times 门" do
    test "betrayer/times > 0 → 叹息+告白拒绝，不进入常规门控" do
      player = build_player(
        temp: %{"pass_zhenlong" => true},
        env: %{"betrayer" => %{"times" => 2}}
      )
      conn = build_conn(player)

      result = FamilyEvent.result(
        conn,
        %Event{topic: "family/result", data: recruit_data()}
      )

      # 拒绝：不写入 family
      assert result.private.update_character == nil
      assert output_text(result) =~ "你背叛过师门，我不收你"
      # 房间广播：叹息 + 告白
      assert vision_text(result) =~ "叹了口气"
      assert vision_text(result) =~ "无崖子说道：你背叛过师门，我不收你"
      # 不写入 family（被拒收）
      assert Map.get(result.character.meta, :family) == nil
    end

    test "betrayer/times == 0 → 通过，记录 betryer/times=0" do
      player = build_player(
        temp: %{"pass_zhenlong" => true},
        env: %{"betrayer" => %{"times" => 0}}
      )
      conn = build_conn(player)

      result = FamilyEvent.result(
        conn,
        %Event{topic: "family/result", data: recruit_data()}
      )

      enrolled = result.private.update_character || result.character
      assert enrolled.meta.family.name == "逍遥派"
      assert Map.get(enrolled.meta.env, "betryer") == %{times: 0}
    end

    test "betrayer 缺失 → 视为 0，通过" do
      player = build_player(
        temp: %{"pass_zhenlong" => true},
        env: %{}
      )
      conn = build_conn(player)

      result = FamilyEvent.result(
        conn,
        %Event{topic: "family/result", data: recruit_data()}
      )

      enrolled = result.private.update_character || result.character
      assert enrolled.meta.family.name == "逍遥派"
      assert Map.get(enrolled.meta.env, "betryer") == %{times: 0}
    end
  end

  describe "传功（max_neili < 500）" do
    test "max_neili < 500 → 内力上限提至 500+random(100)，force/bei ming shengong 提至 50+random(10)" do
      player = build_player(
        temp: %{"pass_zhenlong" => true},
        max_neili: 300,
        stats: %Stats{
          skills: %{"xiaoyao-xinfa" => 150, "force" => 130, "dodge" => 150, "beiming-shengong" => 20},
          int: 45,
          per: 30,
          combat_exp: 600_000,
          shen: 0
        }
      )
      conn = build_conn(player)

      result = FamilyEvent.result(
        conn,
        %Event{topic: "family/result", data: recruit_data()}
      )

      enrolled = result.private.update_character || result.character
      new_max_neili = enrolled.meta.vitals.max_neili
      assert new_max_neili >= 500 and new_max_neili <= 600
      assert enrolled.meta.stats.skills["force"] == 130
      assert enrolled.meta.stats.skills["beiming-shengong"] >= 50 and enrolled.meta.stats.skills["beiming-shengong"] <= 60
      assert enrolled.meta.family.name == "逍遥派"

      # vision 广播
      assert vision_text(result) =~ "传你一股内力助你一臂之力"
    end

    test "force >= 50 且 beiming-shengong >= 50 → 不覆盖现有等级" do
      player = build_player(
        temp: %{"pass_zhenlong" => true},
        max_neili: 300,
        stats: %Stats{
          skills: %{"xiaoyao-xinfa" => 150, "force" => 200, "dodge" => 150, "beiming-shengong" => 200},
          int: 45,
          per: 30,
          combat_exp: 600_000,
          shen: 0
        }
      )
      conn = build_conn(player)

      result = FamilyEvent.result(
        conn,
        %Event{topic: "family/result", data: recruit_data()}
      )

      enrolled = result.private.update_character || result.character
      assert enrolled.meta.stats.skills["force"] == 200
      assert enrolled.meta.stats.skills["beiming-shengong"] == 200
      assert enrolled.meta.family.name == "逍遥派"
    end

    test "max_neili >= 500 → 不传功，直接进入常规门控" do
      player = build_player(
        temp: %{"pass_zhenlong" => true},
        max_neili: 800,
        stats: %Stats{
          skills: %{"xiaoyao-xinfa" => 150, "force" => 150, "dodge" => 150},
          int: 45,
          per: 30,
          combat_exp: 600_000,
          shen: 0
        }
      )
      conn = build_conn(player)

      result = FamilyEvent.result(
        conn,
        %Event{topic: "family/result", data: recruit_data()}
      )

      enrolled = result.private.update_character || result.character
      assert enrolled.meta.vitals.max_neili == 800
      assert enrolled.meta.family.name == "逍遥派"
      # 无 vision 广播（未传功）
      refute vision_text(result) =~ "传你一股内力"
    end
  end

  describe "常规门控拒绝（珍珓分支通过后仍被 recruit_gate? 拦截）" do
    test "exp 不足 → 珍珓分支传功后，常规门控仍拒绝" do
      player = build_player(
        temp: %{"pass_zhenlong" => true},
        max_neili: 300,
        stats: %Stats{
          skills: %{"xiaoyao-xinfa" => 150, "force" => 150, "dodge" => 150},
          int: 45,
          per: 30,
          combat_exp: 100_000,
          shen: 0
        }
      )
      conn = build_conn(player)

      result = FamilyEvent.result(
        conn,
        %Event{topic: "family/result", data: recruit_data()}
      )

      # 珍珓分支执行（传功），但 exp 不足被常规门控拒绝
      assert result.private.update_character == nil
      assert output_text(result) =~ "经验尚浅"
      # 传功仍然生效（vision 广播已发出，max_neili 已落盘）
      assert vision_text(result) =~ "传你一股内力助你一臂之力"
    end
  end
end
