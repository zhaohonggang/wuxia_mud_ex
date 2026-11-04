defmodule Kantele.Character.RebornTest do
  @moduledoc """
  转世重生测试（对应 LPC `updated.c` zhuan_player + `dizangwang.c` 四前置，updated.c:447-745）。

  覆盖：大宗师阈值、四前置齐备判定、zhuan_player 清记录/清零/删武功/赠特技/保留注册
  相关 env（startroom/setup_done/gender/born/surname/registered/special_skills/reborn）、
  以及 save→load→apply 往返后特技与出生地不丢。
  """
  use ExVenture.DataCase, async: false

  alias Kalevala.Character
  alias Kalevala.Event
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Character.Reborn
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills.WudoumiShengong
  alias Kantele.NPC.Dizangwang

  @name "reborn-test-#{System.unique_integer([:positive])}"

  defp character(opts) do
    stats =
      Stats.new()
      |> Map.put(:combat_exp, Keyword.get(opts, :combat_exp, 0))
      |> Map.put(:reborn, %{str: 0, int: 0, con: 0, dex: 0})

    %Character{
      id: "reborn-#{@name}",
      name: @name,
      pid: self(),
      room_id: "register:yanluodian",
      attributes: %{},
      inventory: [],
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: stats,
        combat: Combat.new(),
        coins: 100,
        # 注册完成的回归玩家：zhuan_player 保留 setup_done（真实转世玩家从登录
        # apply_to_character 恢复后该字段即 true；此处显式置 true 以闭合 round-trip 断言）
        setup_done: true,
        env:
          Map.merge(
            %{
              gender: "男性",
              born: "扬州人氏",
              born_family: "没有",
              surname: nil,
              registered: true,
              startroom: "city:kedian",
              setup_done: true,
              reborn: %{count: 1, point: 1, family: %{}}
            },
            Keyword.get(opts, :env, %{})
          )
      }
    }
  end

  describe "前置判定" do
    test "大宗师：combat_exp≥800M 才 true" do
      refute Reborn.ultrap?(character(combat_exp: 799_999_999))
      assert Reborn.ultrap?(character(combat_exp: 800_000_000))
      assert Reborn.ultrap?(character(combat_exp: 900_000_000))
    end

    test "四前置齐备才放行" do
      base = character(combat_exp: 800_000_000, env: %{HellZhenPass: true, DiZangPass: true, SkyPass: true})
      assert Reborn.prereqs_met?(base)

      refute Reborn.prereqs_met?(character(combat_exp: 100))  # 缺大宗师
      refute Reborn.prereqs_met?(put_in(base, [Access.key(:meta), Access.key(:env), Access.key(:HellZhenPass)], nil))
      refute Reborn.prereqs_met?(put_in(base, [Access.key(:meta), Access.key(:env), Access.key(:DiZangPass)], nil))
      refute Reborn.prereqs_met?(put_in(base, [Access.key(:meta), Access.key(:env), Access.key(:SkyPass)], nil))
    end
  end

  describe "zhuan_player 主体" do
    test "清记录 + 清零 + 删武功 + 保留注册相关 env" do
      c =
        character(env: %{HellZhenPass: true, DiZangPass: true, SkyPass: true})
        |> Map.put(:attributes, %{"special_skills" => %{"agile" => true}})
        |> Reborn.zhuan_player()

      # 数值清零
      assert c.meta.stats.combat_exp == 0
      assert c.meta.stats.score == 0
      assert c.meta.stats.weiwang == 0
      assert c.meta.stats.gongxian == 0
      assert c.meta.stats.shen == 0

      # 气血/精力
      assert c.meta.vitals.max_qi == 100 and c.meta.vitals.qi == 100
      assert c.meta.vitals.max_jing == 100 and c.meta.vitals.jing == 100
      assert c.meta.vitals.max_neili == 0 and c.meta.vitals.neili == 0

      # 删全部武功
      assert c.meta.stats.skills == %{}
      assert c.meta.stats.mapped == %{}

      # 身份
      assert c.meta.character == "国士无双"
      assert c.meta.title == "江湖游侠"

      # 保留注册相关 env
      env = c.meta.env
      assert env[:startroom] == "city:kedian"
      assert env[:setup_done] == true
      assert env[:gender] == "男性"
      assert env[:born] == "扬州人氏"
      assert env[:registered] == true

      # 前置标记已清
      refute Map.has_key?(env, :HellZhenPass)
      refute Map.has_key?(env, :DiZangPass)
      refute Map.has_key?(env, :SkyPass)
      assert env[:mud_age] == 0
      assert env[:age] == 14

      # 清记录字段
      assert c.meta.family == nil
      assert c.meta.league == %{}
      assert c.meta.brothers == []
      assert c.meta.spouse == %{}
      assert c.meta.marks == %{}
    end

    test "「无性」→「男性」" do
      c = character(env: %{HellZhenPass: true, DiZangPass: true, SkyPass: true, gender: "无性"})
      c2 = Reborn.zhuan_player(c)
      assert c2.meta.env[:gender] == "男性"
    end

    test "reborn/count 与 point +1；reborn 属性加成 ∈ {0,1}" do
      c =
        character(env: %{HellZhenPass: true, DiZangPass: true, SkyPass: true, reborn: %{count: 3, point: 2, family: %{"a" => 1}}})
        |> Reborn.zhuan_player()

      assert c.meta.env[:reborn][:count] == 4
      assert c.meta.env[:reborn][:point] == 3
      # family 子键已清
      refute Map.has_key?(c.meta.env[:reborn], :family)

      for k <- [:str, :con, :int, :dex] do
        val = c.meta.stats.reborn[k]
        assert val in 0..1, "reborn.#{k} 应为 0 或 1，实际 #{val}"
      end
    end

    test "赠特技：固定神眼 + 普通(排除已拥有) + 转世；「与生俱来」特技保留" do
      c =
        character(env: %{HellZhenPass: true, DiZangPass: true, SkyPass: true})
        |> Map.put(:attributes, %{"special_skills" => %{"agile" => true}})
        |> Reborn.zhuan_player()

      ss = c.attributes["special_skills"]
      # 固定神眼
      assert ss["shenyan"] == true
      # 已拥有的普通特技保留
      assert ss["agile"] == true
      # 至少还应获得 1 普通 + 1 转世（+ 可能 tiandao/clever）
      assert map_size(ss) >= 3

      # env 镜像同步
      assert "shenyan" in c.meta.env[:special_skills]
      assert "agile" in c.meta.env[:special_skills]
    end

    test "int<16 兜底赠天道酬勤(tiandao)，否则赠天赋聪颖(clever)" do
      low = character(combat_exp: 800_000_000, env: %{HellZhenPass: true, DiZangPass: true, SkyPass: true})
      # 把 int 压到 <16
      low = put_in(low, [Access.key(:meta), Access.key(:stats), Access.key(:int)], 10)
      low = Reborn.zhuan_player(low)
      assert low.attributes["special_skills"]["tiandao"] == true

      high = character(env: %{HellZhenPass: true, DiZangPass: true, SkyPass: true})
      high = put_in(high, [Access.key(:meta), Access.key(:stats), Access.key(:int)], 30)
      high = Reborn.zhuan_player(high)
      assert high.attributes["special_skills"]["clever"] == true
    end

    test "转世技能过滤：int<22 或 dex<26 不赠鬼脉(guimai)" do
      c = character(env: %{HellZhenPass: true, DiZangPass: true, SkyPass: true})
      c = put_in(c, [Access.key(:meta), Access.key(:stats), Access.key(:int)], 20)
      c = put_in(c, [Access.key(:meta), Access.key(:stats), Access.key(:dex)], 20)
      c = Reborn.zhuan_player(c)
      refute Map.has_key?(c.attributes["special_skills"], "guimai")
    end
  end

  describe "落盘往返（save→load→apply）" do
    test "转世后出生地与特技经 Records 不丢" do
      c =
        character(env: %{HellZhenPass: true, DiZangPass: true, SkyPass: true})
        |> Map.put(:attributes, %{"special_skills" => %{"agile" => true}})
        |> Reborn.zhuan_player()

      assert :ok = Records.save(c)
      {:ok, metadata, _wiz} = Records.load(@name)
      restored = Records.apply_to_character(c, {:ok, metadata}, 0)

      # 出生地/setup_done 保留
      assert restored.meta.env[:startroom] == "city:kedian"
      assert restored.meta.env[:setup_done] == true
      assert restored.room_id == "city:kedian"

      # 转世身份落盘
      assert restored.meta.character == "国士无双"

      # 特技（含保留的 agile + 新赠 shenyan 等）回灌
      assert restored.attributes["special_skills"]["agile"] == true
      assert restored.attributes["special_skills"]["shenyan"] == true
    end
  end

  describe "转世触发 (Reborn.trigger，对应 ask_zhuan 入口)" do
    test "四前置齐备 + 大宗师 → trigger 返回 {:ok, character} 且落盘；身份变国士无双" do
      c =
        character(combat_exp: 800_000_000, env: %{HellZhenPass: true, DiZangPass: true, SkyPass: true})
        |> Map.put(:attributes, %{"special_skills" => %{"agile" => true}})

      assert {:ok, reborn} = Reborn.trigger(c)
      assert reborn.meta.character == "国士无双"
      assert reborn.meta.stats.combat_exp == 0
      assert reborn.meta.env[:reborn][:count] == 2

      # 落盘往返：身份持久化
      {:ok, metadata, _wiz} = Records.load(@name)
      restored = Records.apply_to_character(c, {:ok, metadata}, 0)
      assert restored.meta.character == "国士无双"
    end

    test "缺任意前置 → trigger 返回 {:error, 拒绝语} 且指明缺项" do
      # 缺大宗师（combat_exp 不足）
      miss_ultrap = character(env: %{HellZhenPass: true, DiZangPass: true, SkyPass: true})
      assert {:error, msg1} = Reborn.trigger(miss_ultrap)
      assert msg1 =~ "大宗师"

      # 四前置齐但缺 HellZhenPass
      miss_hell = character(combat_exp: 800_000_000, env: %{DiZangPass: true, SkyPass: true})
      assert {:error, msg2} = Reborn.trigger(miss_hell)
      assert msg2 =~ "十八层地狱"

      # missing_prereqs 精确列出缺项
      missing = Reborn.missing_prereqs(miss_hell)
      assert "十八层地狱未通关（HellZhenPass）" in missing
      refute Reborn.prereqs_met?(miss_hell)
    end

    test "trigger 后 4 包含门技能因国士无双身份而解锁（end-to-end）" do
      c =
        character(combat_exp: 800_000_000, env: %{HellZhenPass: true, DiZangPass: true, SkyPass: true})

      assert {:ok, reborn} = Reborn.trigger(c)
      assert reborn.meta.character == "国士无双"

      # 转世清了 skills/max_neili（与 LPC delete_skill 一致），重练回五斗米神功非性格前置
      ready =
        reborn
        |> put_in([Access.key(:meta), Access.key(:stats), Access.key(:con)], 25)
        |> put_in([Access.key(:meta), Access.key(:stats), Access.key(:skills)], %{"force" => 60, "unarmed" => 60})
        |> put_in([Access.key(:meta), Access.key(:vitals), Access.key(:max_neili)], 600)

      assert :ok = WudoumiShengong.valid_learn(ready.meta.stats, ready)
    end
  end

  describe "地藏王 NPC 处理器 (P4-B 起按 LPC ask_zhuan 分支)" do
    test "check：ask 层只拦 HellZhenPass；未知关键词兜底" do
      ready = character(combat_exp: 800_000_000, env: %{HellZhenPass: true, DiZangPass: true, SkyPass: true})
      assert :ok = Dizangwang.check(ready, %{}, "转世")

      # P4-B 改按 LPC `ask_zhuan` 分步：大宗师/生死斗/献丹不再在 ask 层拦，
      # 由 `Reborn.trigger/1` 于六道轮回末步统一校验四前置。
      no_hell = character(combat_exp: 800_000_000, env: %{DiZangPass: true, SkyPass: true})
      assert {:error, msg} = Dizangwang.check(no_hell, %{}, "转世")
      assert msg =~ "十八层地狱"

      assert {:error, _} = Dizangwang.check(ready, %{}, "不存在的关键词")
    end

    test "execute：已取丹催交 / 未取丹发起生死斗；转世主体仍走 Reborn.trigger（含落盘）" do
      ready = character(combat_exp: 800_000_000, env: %{HellZhenPass: true, DiZangPass: true, SkyPass: true})

      # 分支②：SkyPass 已置 → 催交精元丹，不直接转世
      assert {:error, msg} = Dizangwang.execute(ready, %{}, "转世")
      assert msg =~ "精元丹"

      # 分支③：未取丹 → 发起生死斗，双方各收 combat/start (type kill)
      no_dan = character(combat_exp: 800_000_000, env: %{HellZhenPass: true})
      npc = %{id: "dizangwang", name: "地藏王", pid: self(), room_id: "death:yanluodian"}
      assert :ok = Dizangwang.execute(no_dan, npc, "转世")
      assert_receive %Event{topic: "combat/start", data: %{type: "kill"}}
      assert_receive %Event{topic: "combat/start", data: %{type: "kill"}}

      # 转世主体（清记录 / 国士无双 / 落盘）现在由无间道动画末步调用
      assert {:ok, _reborn} = Reborn.trigger(ready)

      {:ok, metadata, _wiz} = Records.load(@name)
      restored = Records.apply_to_character(ready, {:ok, metadata}, 0)
      assert restored.meta.character == "国士无双"
    end
  end
end
