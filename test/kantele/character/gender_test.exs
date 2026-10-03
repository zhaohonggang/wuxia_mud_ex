defmodule Kantele.Character.GenderTest do
  @moduledoc """
  玩家性别落地链路（LPC `me->query("gender")`）

  背景：`data/world` 有 11 条 `valid_leave` 条件读 `me->query("gender")`。
  之前 `query("...")` 走 `meta.env`，而没有任何地方写 gender，于是：

      me->query('gender') != '男性'   ->  nil != "男性"  ->  **恒真（会误拦）**
      me->query('gender') == '女性'   ->  **恒假（放行）**

  11 条里有 4 条属于「恒真」那类，会把玩家**永久拦死在房外**，
  所以 `LpcCondition.@unsupported_fields` 之前把 gender 整批挡下。

  现在：`character_metadata.gender`（默认「男性」）→
  `Records.apply_to_character/3` 写进 `meta.env["gender"]` →
  `query("gender")` 读得到 → 那份名单空了。

  ## 存量角色

  迁移是 `add(:gender, :string, default: "男性", null: false)`，
  Postgres 会把历史行一并回填成「男性」，所以老角色无需手工处理。
  """
  use ExUnit.Case, async: false

  alias ExVenture.Characters.Metadata
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.World.{ExitVetoContext, LpcCondition}

  describe "Metadata schema" do
    test "gender 字段存在且默认「男性」" do
      assert %Metadata{gender: "男性"} = %Metadata{}
    end

    test "changeset 能 cast gender" do
      # 不断言 cs.valid? —— %Metadata{} 没有 character_id，
      # 而 changeset 对 belongs_to 有必填校验，那与本用例无关。
      cs = Metadata.changeset(%Metadata{}, %{gender: "女性"})
      assert Ecto.Changeset.get_field(cs, :gender) == "女性"
    end

    test "changeset 会拒掉未知取值吗（当前不校验，取值范围由 LPC 语义决定）" do
      cs = Metadata.changeset(%Metadata{}, %{gender: "无性"})
      assert Ecto.Changeset.get_field(cs, :gender) == "无性"
    end
  end

  describe "apply_to_character 把 gender 写进 meta.env" do
    defp loaded_with(metadata) do
      char = %Kalevala.Character{
        id: "gender-test",
        name: "test",
        pid: self(),
        room_id: "city:guangchang",
        attributes: %{},
        inventory: [],
        meta: %PlayerMeta{
          vitals: Kantele.Character.Vitals.new(),
          stats: Kantele.Character.Stats.new(),
          combat: Kantele.Character.Combat.new(),
          temp: %{},
          damage: %{},
          env: %{}
        }
      }

      Records.apply_to_character(char, {:ok, metadata}, 0)
    end

    defp metadata(gender) do
      %Metadata{
        str: 20, dex: 20, con: 20, int: 20,
        combat_exp: 0, potential: 100,
        skills: %{}, mapped: %{}, performs: [],
        equipment: %{}, inventory: [],
        max_neili: 200, max_jingli: 0,
        coins: 100, bank_coins: 0,
        family: %{}, gender: gender
      }
    end

    test "男性写进 env" do
      assert loaded_with(metadata("男性")).meta.env[:gender] == "男性"
    end

    test "女性写进 env" do
      assert loaded_with(metadata("女性")).meta.env[:gender] == "女性"
    end

    test "字段为 nil 时兜底成「男性」（历史脏档也不会让 query 读成 nil）" do
      assert loaded_with(metadata(nil)).meta.env[:gender] == "男性"
    end
  end

  describe "LpcCondition 不再跳过性别条件" do
    test "@unsupported_fields 已空" do
      assert LpcCondition.supported?("me->query('gender') != '男性'")
      assert LpcCondition.supported?("me->query(\"gender\") == '女性'")
    end

    test "11 条性别条件全部变成 supported" do
      for expr <- [
            "me->query('gender') != '男性' && dir == 'east'",
            "me->query('gender') != '女性' && dir == 'west'",
            "me->query('gender') == '女性' && dir == 'east'",
            "(string)me->query('gender') == '男性'"
          ] do
        assert LpcCondition.supported?(expr), "#{expr} 不该再被跳过"
      end
    end
  end

  describe "求值：默认「男性」下的实际行为" do
    defp evaluate(gender, expr, dir) do
      char = %Kalevala.Character{
        id: "g",
        name: "测试玩家",
        pid: self(),
        room_id: "test:room",
        attributes: %{},
        inventory: [],
        meta: %PlayerMeta{
          vitals: Kantele.Character.Vitals.new(),
          stats: Kantele.Character.Stats.new(),
          combat: Kantele.Character.Combat.new(),
          temp: %{},
          env: %{gender: gender}
        }
      }

      ctx =
        ExitVetoContext.build(
          dir: dir,
          me: char,
          room: %Kantele.World.Room{id: "test:room"},
          context: %{characters: []}
        )

      LpcCondition.evaluate(expr, ctx)
    end

    test "男性：!= '男性' 为假（放行）" do
      assert {:ok, false} =
               evaluate("男性", "me->query('gender') != '男性' && dir == 'west'", "west")
    end

    test "男性：!= '女性' 为真（拦人）—— 这正是之前恒真导致误拦的那类" do
      assert {:ok, true} =
               evaluate("男性", "me->query('gender') != '女性' && dir == 'west'", "west")
    end

    test "女性：!= '女性' 为假（放行）" do
      assert {:ok, false} =
               evaluate("女性", "me->query('gender') != '女性' && dir == 'west'", "west")
    end

    test "女性：== '女性' 为真（放行女性专属方向）" do
      assert {:ok, true} =
               evaluate("女性", "me->query('gender') == '女性' && dir == 'east'", "east")
    end

    test "方向不匹配时整条为假（不会误拦其它方向）" do
      assert {:ok, false} =
               evaluate("男性", "me->query('gender') != '女性' && dir == 'west'", "east")
    end
  end
end
