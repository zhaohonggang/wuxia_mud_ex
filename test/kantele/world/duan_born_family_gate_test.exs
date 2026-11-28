defmodule Kantele.World.DuanBornFamilyGateTest do
  @moduledoc """
  #843 大理段氏 `duan.h permit_recruit` 出生家族硬门定向测试。

  覆盖：11 位可收徒 NPC 数据回填、permit_recruit 四门原序
  （叛门 → 叛师 → born_family → 他派）、段正明三道额外门的后置顺序、旧配置零回归。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.SectMaster
  alias Kantele.World.Loader

  @deny "我们段家乃皇族出身，不收外人。"
  @other_deny "你当年跑出去的时候怎么就没想过要回来？"
  @betray_deny "既然离开了我们段家，就不要回来了"
  @betray_times_deny "哼，我们大理段氏最痛恨的就是不忠不义之徒。"

  @recruit_names [
    "巴天石",
    "褚万里",
    "刀白凤",
    "段正淳",
    "段正明",
    "范骅",
    "傅思归",
    "高升泰",
    "古笃诚",
    "华赫艮",
    "朱丹臣"
  ]

  setup_all do
    %{world: Loader.load()}
  end

  defp npc(world, name), do: Enum.find(world.characters, &(&1.name == name))

  defp apprentice(world, name) do
    ob = npc(world, name)
    assert ob, "#{name} 应随世界加载"
    ob.meta.apprentice
  end

  defp student(opts \\ []) do
    env = %{born_family: Keyword.get(opts, :born, "段氏皇族")}

    env =
      case Keyword.get(opts, :detach) do
        nil -> env
        flag -> Map.put(env, :detach, %{"段氏皇族" => flag})
      end

    env =
      case Keyword.get(opts, :betray_times) do
        nil -> env
        times -> Map.put(env, :betrayer, %{times: times})
      end

    meta = %{
      stats: %Stats{
        shen: Keyword.get(opts, :shen, 60_000),
        combat_exp: Keyword.get(opts, :exp, 500_000),
        skills: Keyword.get(opts, :skills, %{"duanshi-xinfa" => 120})
      },
      env: env
    }

    meta =
      case Keyword.get(opts, :family) do
        nil -> meta
        name -> Map.put(meta, :family, %{name: name})
      end

    %{meta: meta}
  end

  describe "UCL 数据回填" do
    test "11 位段氏可收徒 NPC 全部带 born_family 硬门字段", %{world: world} do
      for name <- @recruit_names do
        gate = apprentice(world, name)
        assert gate.permit_recruit == true, "#{name} 应 permit_recruit"
        assert gate.family == "段氏皇族"
        assert gate.required_born_family == "段氏皇族", "#{name} 缺出生家族硬门"
        assert gate.born_family_deny == @deny, "#{name} 出生门文案不符"
        assert gate.betray_sect_deny == @betray_deny
        assert gate.betray_times_deny == @betray_times_deny
        assert gate.other_family_deny == @other_deny
      end
    end

    test "胡斐：hu.h 出生家族硬门与 permit_recruit 三问一并回填", %{world: world} do
      gate = apprentice(world, "胡斐")
      assert gate.required_born_family == "关外胡家"
      assert gate.born_family_deny == "我关外胡家虽然人丁稀少，但也不收纳族外之人。"
      assert gate.betray_sect_deny == "你反复无常，我不能收你为徒！"
      assert gate.other_family_deny == "你既然已经离家拜师，就应有所作为，又跑回来作甚？"

      assert {:error, "我关外胡家虽然人丁稀少，但也不收纳族外之人。\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(born: "段氏皇族", family: "段氏皇族"),
                 gate
               )

      assert {:error, "你既然已经离家拜师，就应有所作为，又跑回来作甚？\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(born: "关外胡家", family: "段氏皇族"),
                 gate
               )

      assert :ok = SectMaster.recruit_gate?(nil, student(born: "关外胡家"), gate)
    end
  end

  describe "permit_recruit 四门原序" do
    test "非段氏出身、未入门派：仍被出生门拒绝", %{world: world} do
      gate = apprentice(world, "巴天石")

      assert {:error, @deny <> "\n"} =
               SectMaster.recruit_gate?(nil, student(born: "武当派"), gate)
    end

    test "非段氏出身且已投他派：出生门先于他派门", %{world: world} do
      gate = apprentice(world, "巴天石")

      assert {:error, @deny <> "\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(born: "武当派", family: "武当派"),
                 gate
               )
    end

    test "段氏出身但已投他派：仍按他派门逐字拒绝", %{world: world} do
      gate = apprentice(world, "巴天石")

      assert {:error, @other_deny <> "\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(born: "段氏皇族", family: "武当派"),
                 gate
               )
    end

    test "叛门/叛师记录先于出生门", %{world: world} do
      gate = apprentice(world, "巴天石")

      assert {:error, @betray_deny <> "\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(born: "武当派", family: "武当派", detach: true),
                 gate
               )

      assert {:error, @betray_times_deny <> "\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(born: "武当派", family: "武当派", betray_times: 1),
                 gate
               )
    end

    test "出生正确且无他派/叛门记录：普通段氏师父直接收徒", %{world: world} do
      gate = apprentice(world, "巴天石")
      assert :ok = SectMaster.recruit_gate?(nil, student(), gate)
    end
  end

  describe "段正明额外门（出生门之后）" do
    test "出生门先于 shen / 心法 / 经验三门", %{world: world} do
      gate = apprentice(world, "段正明")

      assert {:error, @deny <> "\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(born: "武当派", shen: 0, exp: 0, skills: %{}),
                 gate
               )
    end

    test "shen → duanshi-xinfa → combat_exp 逐门命中 LPC 文案", %{world: world} do
      gate = apprentice(world, "段正明")

      assert {:error, "你江湖上的名声不怎么样，这样的人如何能够治好国家？\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(shen: 49_999, exp: 0, skills: %{}),
                 gate
               )

      assert {:error, "你先好好学习我们段家的心法，以后我再指点你。\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(shen: 50_000, exp: 0, skills: %{"duanshi-xinfa" => 99}),
                 gate
               )

      assert {:error, "你实战经验太低，应好好在江湖上历炼，不要失了段氏的面子。\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(shen: 50_000, exp: 399_999, skills: %{"duanshi-xinfa" => 100}),
                 gate
               )
    end

    test "段正明三门全过后收徒成功", %{world: world} do
      gate = apprentice(world, "段正明")

      assert :ok =
               SectMaster.recruit_gate?(
                 nil,
                 student(shen: 50_000, exp: 400_000, skills: %{"duanshi-xinfa" => 100}),
                 gate
               )
    end
  end

  describe "门序调整零回归" do
    test "未配置 required_born_family 的旧配置仍走他派门", %{world: world} do
      gate =
        apprentice(world, "巴天石")
        |> Map.drop([:required_born_family, :born_family_deny])

      assert {:error, @other_deny <> "\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(born: "武当派", family: "武当派"),
                 gate
               )
    end

    test "苗人凤/慕容复出生门仍先于他派门", %{world: world} do
      miao = apprentice(world, "苗人凤")
      murong = apprentice(world, "慕容复")

      assert {:error, "我苗家向来便不收容外人。\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(born: "武当派", family: "武当派"),
                 miao
               )

      assert {:error, "你不是我们慕容家的人，师徒就免了吧。\n"} =
               SectMaster.recruit_gate?(
                 nil,
                 student(born: "武当派", family: "武当派"),
                 murong
               )
    end
  end
end
