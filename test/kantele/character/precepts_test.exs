defmodule Kantele.Character.PreceptsTest do
  @moduledoc """
  S8/E3 戒律系统测试：guilty 写入端（此前仅有 hunyuan-yiqi/buddhism 的读取端 no-op）。

  覆盖：
  - Precepts.violate / guilty_of / clear 纯函数
  - 侦测辅助 meat_item? / monk_name?
  - records.apply_to_character 落盘恢复路径（不依赖 DB）
  - hunyuan-yiqi / buddhism 的 guilty 门在 guilty>0 时真正拦（E3 收口）
  """
  use ExUnit.Case

  alias ExVenture.Characters.Metadata
  alias Kalevala.Character
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Precepts
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills.Buddhism
  alias Kantele.Combat.Skills.HunyuanYiqi

  # ---- 构造辅助 ----------------------------------------------------------

  defp char(opts) do
    opts = if is_list(opts), do: Map.new(opts), else: opts
    stats = Stats.new() |> Map.put(:skills, Map.get(opts, :skills, %{"force" => 30}))

    meta = %PlayerMeta{
      vitals: Vitals.new(),
      stats: stats,
      combat: Combat.new(),
      coins: 100,
      setup_done: true,
      guilty: opts[:guilty] || 0,
      spouse: nil,
      env: %{gender: "男性"}
    }

    %Character{
      id: "precepts-#{System.unique_integer([:positive])}",
      name: "precepts",
      pid: self(),
      room_id: "r",
      attributes: %{},
      inventory: [],
      meta: meta
    }
  end

  # ---- Precepts 纯函数 ---------------------------------------------------

  describe "violate / guilty_of / clear" do
    test "整数 amount 直接累加" do
      c = char(guilty: 0)
      assert Precepts.guilty_of(c) == 0
      c = Precepts.violate(c, 3)
      assert Precepts.guilty_of(c) == 3
      c = Precepts.violate(c, 2)
      assert Precepts.guilty_of(c) == 5
    end

    test "reason 原子映射到预置权重（未知 reason 兜底 +1）" do
      c = Precepts.violate(char(guilty: 0), :eat_meat)
      assert Precepts.guilty_of(c) == 1
      c = Precepts.violate(c, :kill_monk)
      assert Precepts.guilty_of(c) == 2
      c = Precepts.violate(c, :monk_trap)
      assert Precepts.guilty_of(c) == 5
      c = Precepts.violate(c, :unknown_reason)
      assert Precepts.guilty_of(c) == 6
    end

    test "guilty_of 对 nil / 非整数视作 0" do
      assert Precepts.guilty_of(%Character{meta: %{}}) == 0
      assert Precepts.guilty_of(%Character{meta: %{guilty: nil}}) == 0
      assert Precepts.guilty_of(%Character{meta: %{guilty: "x"}}) == 0
      assert Precepts.guilty_of(%Character{meta: %{guilty: 4}}) == 4
      assert Precepts.guilty_of("not a character") == 0
    end

    test "clear 清零（戒律院赦免）" do
      c = Precepts.violate(char(guilty: 5), :eat_meat)
      assert Precepts.guilty_of(c) == 6
      c = Precepts.clear(c)
      assert Precepts.guilty_of(c) == 0
    end

    test "默认 amount 为 1（无参调用）" do
      c = Precepts.violate(char(guilty: 0))
      assert Precepts.guilty_of(c) == 1
    end
  end

  describe "侦测辅助" do
    test "meat_item? 依据 item.meta.is_meat" do
      assert Precepts.meat_item?(%{meta: %{is_meat: true}})
      refute Precepts.meat_item?(%{meta: %{}})
      refute Precepts.meat_item?(%{meta: %{is_meat: false}})
      refute Precepts.meat_item?(%{})
      refute Precepts.meat_item?(nil)
    end

    test "monk_name? 子串启发式（僧/少林/罗汉/达摩/武僧）" do
      assert Precepts.monk_name?("扫地僧")
      assert Precepts.monk_name?("少林弟子")
      assert Precepts.monk_name?("罗汉堂首座")
      assert Precepts.monk_name?("达摩院尊者")
      assert Precepts.monk_name?("武僧")
      refute Precepts.monk_name?("路人甲")
      refute Precepts.monk_name?(nil)
      refute Precepts.monk_name?(42)
    end
  end

  # ---- 落盘恢复（不依赖 DB） ---------------------------------------------

  describe "records.apply_to_character 恢复 guilty" do
    test "从 DB 列 guilty 读回并写入 meta.guilty" do
      base =
        char(guilty: 0)
        |> Map.update!(:meta, fn m -> %{m | vitals: Vitals.new(), stats: Stats.new(), combat: Combat.new()} end)

      md = %Metadata{guilty: 7}
      result = Records.apply_to_character(base, {:ok, md}, 0)
      assert result.meta.guilty == 7
    end

    test "guilty 缺列时退化为 0（旧档兼容）" do
      base =
        char(guilty: 3)
        |> Map.update!(:meta, fn m -> %{m | vitals: Vitals.new(), stats: Stats.new(), combat: Combat.new()} end)

      md = %Metadata{}
      result = Records.apply_to_character(base, {:ok, md}, 0)
      assert result.meta.guilty == 0
    end
  end

  # ---- E3 收口：guilty 门真正生效 ----------------------------------------

  describe "guilty 门在 guilty>0 时拦（E3 收口）" do
    test "hunyuan-yiqi：其余前置满足、guilty=0 放行；guilty>0 拦" do
      clean = char(guilty: 0)
      assert :ok = HunyuanYiqi.valid_learn(clean.meta.stats, clean)

      sinned = char(guilty: 1)
      assert {:error, msg} = HunyuanYiqi.valid_learn(sinned.meta.stats, sinned)
      assert msg =~ "屡犯僧家数戒"
    end

    test "buddhism：guilty=0 放行；guilty>0 拦" do
      clean = char(guilty: 0)
      assert :ok = Buddhism.valid_learn(clean.meta.stats, clean)

      sinned = char(guilty: 1)
      assert {:error, msg} = Buddhism.valid_learn(sinned.meta.stats, sinned)
      assert msg =~ "屡犯僧家数戒"
    end

    test "violate 后 hunyuan-yiqi 由放行转为拦截" do
      c = char(guilty: 0)
      assert :ok = HunyuanYiqi.valid_learn(c.meta.stats, c)

      c = Precepts.violate(c, :eat_meat)
      assert {:error, _} = HunyuanYiqi.valid_learn(c.meta.stats, c)
    end
  end
end
