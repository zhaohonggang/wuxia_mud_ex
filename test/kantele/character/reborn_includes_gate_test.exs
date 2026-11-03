defmodule Kantele.Character.RebornIncludesGateTest do
  @moduledoc """
  Phase 2.10 解锁验证：转世后 `meta.character="国士无双"` 应使 4 个「包含门」技能
  （先天功 / 刀剑归真 / 三无三不手 / 五斗米神功）的 `valid_learn` 放行。

  对应 LPC 性格门：`query("character") != <允许值> && != "国士无双"` → 拒。
  普通玩家 `meta.character` 恒 nil（等价 LPC 0），故被性格门拦；转世置「国士无双」
  后该门放行（其余 int/con/技能/内力前置仍需自练，与 LPC 一致）。
  """
  use ExUnit.Case

  alias Kalevala.Character
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Reborn
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills.DaojianGuizhen
  alias Kantele.Combat.Skills.SanwuShou
  alias Kantele.Combat.Skills.WudoumiShengong
  alias Kantele.Combat.Skills.XiantianGong

  # 构造满足「非性格」前置的角色（int/con/dex/性别/技能/内力等），
  # `meta.character` 由 opts[:character] 控制（nil = 普通玩家；"国士无双" = 转世）。
  defp gate_char(opts) do
    stats = Stats.new()

    stats =
      if s = opts[:stats] do
        struct!(stats, s)
      else
        stats
      end

    vitals = Vitals.new() |> Map.put(:max_neili, opts[:max_neili] || 1000)

    env = Map.merge(%{gender: "男性"}, opts[:env] || %{})

    meta = %PlayerMeta{
      vitals: vitals,
      stats: stats,
      combat: Combat.new(),
      coins: 100,
      setup_done: true,
      character: opts[:character],
      env: env
    }

    %Character{
      id: "gate-#{System.unique_integer([:positive])}",
      name: "gate",
      pid: self(),
      room_id: "x",
      attributes: %{},
      inventory: [],
      meta: meta
    }
  end

  defp reborn_identity(char) do
    %{char | meta: %{char.meta | character: "国士无双"}}
  end

  describe "转世解锁验证（4 包含门技能 valid_learn）" do
    test "先天功：性格须『光明磊落』或『国士无双』；转世后放行" do
      c =
        gate_char(%{
          stats: %{int: 35, con: 35, skills: %{"taoism" => 200, "force" => 200, "unarmed" => 200}},
          max_neili: 4000
        })

      assert {:error, msg} = XiantianGong.valid_learn(c.meta.stats, c)
      assert msg =~ "依自己的天性"
      assert :ok = XiantianGong.valid_learn(reborn_identity(c).meta.stats, reborn_identity(c))
    end

    test "刀剑归真：性格须『光明磊落』或『国士无双』；转世后放行" do
      c =
        gate_char(%{
          stats: %{
            int: 36,
            dex: 26,
            skills: %{"martial-cognize" => 250, "sword" => 250, "blade" => 250}
          },
          max_neili: 5000
        })

      assert {:error, msg} = DaojianGuizhen.valid_learn(c.meta.stats, c)
      assert msg =~ "什么刀剑合一"
      assert :ok = DaojianGuizhen.valid_learn(reborn_identity(c).meta.stats, reborn_identity(c))
    end

    test "三无三不手：性格须『心狠手辣』或『国士无双』；转世后放行" do
      c =
        gate_char(%{
          stats: %{skills: %{"force" => 130, "whip" => 110}},
          max_neili: 1000
        })

      assert {:error, msg} = SanwuShou.valid_learn(c.meta.stats, c)
      assert msg =~ "心狠手辣"
      assert :ok = SanwuShou.valid_learn(reborn_identity(c).meta.stats, reborn_identity(c))
    end

    test "五斗米神功：性格须『心狠手辣』或『国士无双』；转世后放行" do
      c =
        gate_char(%{
          stats: %{con: 25, skills: %{"force" => 60, "unarmed" => 60}},
          max_neili: 600
        })

      assert {:error, msg} = WudoumiShengong.valid_learn(c.meta.stats, c)
      assert msg =~ "损人不利己"
      assert :ok = WudoumiShengong.valid_learn(reborn_identity(c).meta.stats, reborn_identity(c))
    end

    test "end-to-end：经 Reborn.zhuan_player 获『国士无双』后，五斗米神功可学" do
      # 满足五斗米神功非性格前置（con/force/unarmed/内力），性格留 nil
      c =
        gate_char(%{
          stats: %{con: 25, skills: %{"force" => 60, "unarmed" => 60}},
          max_neili: 600
        })

      # 转世前被性格门拦
      assert {:error, _} = WudoumiShengong.valid_learn(c.meta.stats, c)

      # 经转世：zhuan_player 置 meta.character="国士无双"，但会清 skills/max_neili
      # （与 LPC delete_skill 一致），此处模拟转世后重新练回前置
      reborn = Reborn.zhuan_player(c)
      assert reborn.meta.character == "国士无双"

      restored =
        reborn
        |> put_in([Access.key(:meta), Access.key(:stats), Access.key(:skills)],
          %{"force" => 60, "unarmed" => 60}
        )
        |> put_in([Access.key(:meta), Access.key(:vitals), Access.key(:max_neili)], 600)

      # 转世身份 + 前置练回 → 放行
      assert :ok = WudoumiShengong.valid_learn(restored.meta.stats, restored)
    end

    test "未转世（普通玩家 nil）即使其它前置满足，仍被 4 门性格门拦" do
      chars = [
        {XiantianGong,
         gate_char(%{
           stats: %{int: 35, con: 35, skills: %{"taoism" => 200, "force" => 200, "unarmed" => 200}},
           max_neili: 4000
         })},
        {DaojianGuizhen,
         gate_char(%{
           stats: %{int: 36, dex: 26, skills: %{"martial-cognize" => 250, "sword" => 250, "blade" => 250}},
           max_neili: 5000
         })},
        {SanwuShou, gate_char(%{stats: %{skills: %{"force" => 130, "whip" => 110}}, max_neili: 1000})},
        {WudoumiShengong,
         gate_char(%{stats: %{con: 25, skills: %{"force" => 60, "unarmed" => 60}}, max_neili: 600})}
      ]

      for {skill, char} <- chars do
        assert {:error, _} = skill.valid_learn(char.meta.stats, char),
               "普通玩家应被 #{skill} 性格门拦截"
      end
    end
  end
end
