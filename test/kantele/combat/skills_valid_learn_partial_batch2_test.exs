defmodule Kantele.Combat.SkillsValidLearnPartialBatch2Test do
  @moduledoc """
  F4 valid_learn 长尾补全——批次 2：

  arity-1 `valid_learn(stats)`（仅 query_skill 门槛，无 character/vitals 访问）：

  - `baicao-jue`：medical>=150、yaowang-miaoshu>=150、medical>=本门、yaowang-miaoshu>=本门
  - `baji-quan`：baihua-cuoquan==0、unarmed>=本门、cuff>=本门
  - `culture-cognize`：恒拒绝（文学修养无法通过学习获得）
  - `huntian-baojian`：恒拒绝（天书混沌无法学习）
  - `huzhao-shou`：baihua-cuoquan==0、claw>=本门
  - `japanese`：literate>=100、literate>=本门
  - `necromancy`：longxiang>=本门
  - `russian`：literate>=100、literate>=本门
  - `tadpole`：literate>=100、literate>=本门
  - `technic-cognize`：恒拒绝（技能修养无法通过学习获得）
  - `wuxing-jueming`：throwing>=100、throwing>=本门
  - `xuwen-qixingding`：throwing>=20、throwing>=本门
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills

  defp stats(skills \\ %{}, attrs \\ %{}) do
    base = Stats.new()
    stats = %{base | skills: Map.merge(base.skills, skills)}
    Enum.reduce(attrs, stats, fn {k, v}, acc -> Map.put(acc, k, v) end)
  end

  defp char(opts \\ []) do
    meta = %{
      vitals: %{
        max_neili: Keyword.get(opts, :max_neili, 20_000),
        neili: Keyword.get(opts, :neili, 20_000)
      },
      env: %{gender: Keyword.get(opts, :gender, "男性")},
      combat: %{equipped: Keyword.get(opts, :equipped, %{})}
    }
    %{meta: meta}
  end

  defp learn(id, stats, character), do: Skills.get(id).valid_learn(stats, character)

  defp assert_error(id, stats, character, fragment) do
    assert {:error, message} = learn(id, stats, character)
    assert message =~ fragment
  end

  # ---- baicao-jue：medical / yaowang-miaoshu 门 ----

  test "baicao-jue：medical < 150 → 拦" do
    assert_error("baicao-jue", stats(%{"yaowang-miaoshu" => 200, "baicao-jue" => 10}), char(), "基本医术造诣太浅")
  end

  test "baicao-jue：yaowang-miaoshu < 150 → 拦" do
    assert_error("baicao-jue", stats(%{"medical" => 200, "baicao-jue" => 10}), char(), "药王妙术造诣太浅")
  end

  test "baicao-jue：medical < 本门 → 拦" do
    assert_error("baicao-jue", stats(%{"medical" => 150, "yaowang-miaoshu" => 200, "baicao-jue" => 200}), char(), "基本医术水平有限")
  end

  test "baicao-jue：yaowang-miaoshu < 本门 → 拦" do
    assert_error("baicao-jue", stats(%{"medical" => 200, "yaowang-miaoshu" => 150, "baicao-jue" => 200}), char(), "药王妙术水平有限")
  end

  test "baicao-jue：全部达标 → :ok" do
    assert :ok = learn("baicao-jue", stats(%{"medical" => 200, "yaowang-miaoshu" => 200, "baicao-jue" => 100}), char())
  end

  # ---- baji-quan：baihua-cuoquan / unarmed / cuff 门 ----

  test "baji-quan：baihua-cuoquan > 0 → 拦" do
    assert_error("baji-quan", stats(%{"baihua-cuoquan" => 1, "unarmed" => 200, "cuff" => 200, "baji-quan" => 100}), char(), "已经练成了百花错拳")
  end

  test "baji-quan：unarmed < 本门 → 拦" do
    assert_error("baji-quan", stats(%{"unarmed" => 50, "cuff" => 200, "baji-quan" => 100}), char(), "基本拳脚火候不足")
  end

  test "baji-quan：cuff < 本门 → 拦" do
    assert_error("baji-quan", stats(%{"unarmed" => 200, "cuff" => 50, "baji-quan" => 100}), char(), "拳法根基火候不足")
  end

  test "baji-quan：全部达标 → :ok" do
    assert :ok = learn("baji-quan", stats(%{"unarmed" => 200, "cuff" => 200, "baji-quan" => 100}), char())
  end

  # ---- culture-cognize：恒拒绝 ----

  test "culture-cognize：任意角色均拒绝" do
    assert_error("culture-cognize", stats(), char(), "文学修养是你文化方面的体会")
  end

  # ---- huntian-baojian：恒拒绝 ----

  test "huntian-baojian：任意角色均拒绝" do
    assert_error("huntian-baojian", stats(), char(), "……—（")
  end

  # ---- huzhao-shou：baihua-cuoquan / claw 门 ----

  test "huzhao-shou：baihua-cuoquan > 0 → 拦" do
    assert_error("huzhao-shou", stats(%{"baihua-cuoquan" => 1, "claw" => 200, "huzhao-shou" => 100}), char(), "已经练成了百花错拳")
  end

  test "huzhao-shou：claw < 本门 → 拦" do
    assert_error("huzhao-shou", stats(%{"claw" => 50, "huzhao-shou" => 100}), char(), "基本爪法火候不足")
  end

  test "huzhao-shou：全部达标 → :ok" do
    assert :ok = learn("huzhao-shou", stats(%{"claw" => 200, "huzhao-shou" => 100}), char())
  end

  # ---- japanese / russian / tadpole：literate 门 ----

  test "japanese：literate < 100 → 拦" do
    assert_error("japanese", stats(%{"literate" => 50, "japanese" => 10}), char(), "读书写字都没学好")
  end

  test "japanese：literate < 本门 → 拦" do
    assert_error("japanese", stats(%{"literate" => 100, "japanese" => 200}), char(), "读书写字水平有限")
  end

  test "japanese：全部达标 → :ok" do
    assert :ok = learn("japanese", stats(%{"literate" => 200, "japanese" => 100}), char())
  end

  test "russian：literate < 100 → 拦" do
    assert_error("russian", stats(%{"literate" => 50, "russian" => 10}), char(), "读书写字都没学好")
  end

  test "russian：literate < 本门 → 拦" do
    assert_error("russian", stats(%{"literate" => 100, "russian" => 200}), char(), "读书写字水平有限")
  end

  test "russian：全部达标 → :ok" do
    assert :ok = learn("russian", stats(%{"literate" => 200, "russian" => 100}), char())
  end

  test "tadpole：literate < 100 → 拦" do
    assert_error("tadpole", stats(%{"literate" => 50, "tadpole" => 10}), char(), "读书写字都没学好")
  end

  test "tadpole：literate < 本门 → 拦" do
    assert_error("tadpole", stats(%{"literate" => 100, "tadpole" => 200}), char(), "读书写字水平有限")
  end

  test "tadpole：全部达标 → :ok" do
    assert :ok = learn("tadpole", stats(%{"literate" => 200, "tadpole" => 100}), char())
  end

  # ---- necromancy：longxiang 门 ----

  test "necromancy：longxiang < 本门 → 拦" do
    assert_error("necromancy", stats(%{"longxiang" => 50, "necromancy" => 100}), char(), "龙相般若功太低了")
  end

  test "necromancy：全部达标 → :ok" do
    assert :ok = learn("necromancy", stats(%{"longxiang" => 200, "necromancy" => 100}), char())
  end

  # ---- technic-cognize：恒拒绝 ----

  test "technic-cognize：任意角色均拒绝" do
    assert_error("technic-cognize", stats(), char(), "技能修养是你工艺技能方面的体会")
  end

  # ---- wuxing-jueming：throwing 门 ----

  test "wuxing-jueming：throwing < 100 → 拦" do
    assert_error("wuxing-jueming", stats(%{"throwing" => 50, "wuxing-jueming" => 10}), char(), "暗器技能不够娴熟")
  end

  test "wuxing-jueming：throwing < 本门 → 拦" do
    assert_error("wuxing-jueming", stats(%{"throwing" => 100, "wuxing-jueming" => 200}), char(), "基本暗器水平有限")
  end

  test "wuxing-jueming：全部达标 → :ok" do
    assert :ok = learn("wuxing-jueming", stats(%{"throwing" => 200, "wuxing-jueming" => 100}), char())
  end

  # ---- xuwen-qixingding：throwing 门 ----

  test "xuwen-qixingding：throwing < 20 → 拦" do
    assert_error("xuwen-qixingding", stats(%{"throwing" => 10, "xuwen-qixingding" => 10}), char(), "暗器技能不够娴熟")
  end

  test "xuwen-qixingding：throwing < 本门 → 拦" do
    assert_error("xuwen-qixingding", stats(%{"throwing" => 20, "xuwen-qixingding" => 100}), char(), "基本暗器水平有限")
  end

  test "xuwen-qixingding：全部达标 → :ok" do
    assert :ok = learn("xuwen-qixingding", stats(%{"throwing" => 200, "xuwen-qixingding" => 100}), char())
  end

  # ---- 覆盖性：12 个技能均已注册并导出 valid_learn/2 ----

  test "12 个 arity-1 技能均已注册并可调用 valid_learn/2" do
    for id <- ~w(baicao-jue baji-quan culture-cognize huntian-baojian huzhao-shou japanese necromancy russian tadpole technic-cognize wuxing-jueming xuwen-qixingding) do
      assert Skills.get(id) != nil, "#{id} 未注册"
      assert function_exported?(Skills.get(id), :valid_learn, 2), "#{id} 缺 valid_learn/2"
    end
  end

  test "任意角色形状下不抛异常" do
    shapes = [
      %{},
      char(),
      char(gender: "无性"),
      %{meta: %{vitals: %{max_neili: nil, neili: nil}, env: %{gender: nil}}},
      %{meta: %{vitals: %{max_neili: 1000, neili: 1000}, env: %{gender: "无性"}}}
    ]

    for id <- ~w(baicao-jue baji-quan culture-cognize huntian-baojian huzhao-shou japanese necromancy russian tadpole technic-cognize wuxing-jueming xuwen-qixingding), shape <- shapes do
      case learn(id, stats(), shape) do
        :ok -> :ok
        {:error, message} -> assert is_binary(message) and message != ""
        other -> flunk("#{id} 返回了非法值：#{inspect(other)}")
      end
    end
  end
end
