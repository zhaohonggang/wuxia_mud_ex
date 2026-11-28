defmodule Kantele.World.DuanImproveSkillsTest do
  @moduledoc """
  #846 大理段氏 14 条 `sect_master_grant` 的 `improve_skills` 逐技能提升量核对。

  LPC 权威：`kungfu/class/duan/*.c` 每次 `me->improve_skill(skill, 1500000)`
  在 ex 引擎中对应数组中的一项 +1；重复调用必须以重复元素保留。
  """

  use ExUnit.Case, async: true

  alias Kantele.World.Loader

  @grants [
    {"刀白凤", "dali:yuxuguan", "凤栖于梧", ["whip", "feifeng-bian", "martial-cognize"]},
    {"段正淳", "dali:neitang", "乾阳神指", ["finger", "qiantian-zhi", "martial-cognize"]},
    {"段正淳", "dali:neitang", "惊天一剑", ["sword", "duanjia-jian", "martial-cognize"]},
    {"段正淳", "dali:neitang", "金玉满堂", ["cuff", "jinyu-quan", "martial-cognize"]},
    {"段正淳", "dali:neitang", "风云变幻", ["strike", "wuluo-zhang", "martial-cognize"]},
    {"段正明", "dali:qiandian", "一指乾坤",
     [
       "force",
       "jingluo-xue",
       "finger",
       "yiyang-zhi",
       "martial-cognize"
     ]},
    {"段正明", "dali:qiandian", "五绝连环", ["sword", "duanjia-jian", "martial-cognize"]},
    {"段正明", "dali:qiandian", "神指点穴",
     [
       "force",
       "jingluo-xue",
       "finger",
       "yiyang-zhi",
       "martial-cognize"
     ]},
    {"段正明", "dali:qiandian", "起死回生",
     [
       "force",
       "jingluo-xue",
       "finger",
       "yiyang-zhi",
       "martial-cognize"
     ]},
    {"古笃诚", "dali:tingfang", "错字诀", ["hammer", "pangen-cuojiefu", "martial-cognize"]},
    {"华赫艮", "dali:situ", "弑元诀", ["claw", "yuezhao-gong", "martial-cognize"]},
    {"一灯大师", "dali:qingchi", "先天功乾阳剑气",
     [
       "force",
       "force",
       "force",
       "finger",
       "finger",
       "finger",
       "xiantian-gong",
       "xiantian-gong",
       "yiyang-zhi",
       "yiyang-zhi",
       "martial-cognize"
     ]},
    {"一灯大师", "dali:qingchi", "阳关三叠",
     [
       "force",
       "force",
       "force",
       "jingluo-xue",
       "jingluo-xue",
       "jingluo-xue",
       "finger",
       "finger",
       "finger",
       "yiyang-zhi",
       "yiyang-zhi",
       "yiyang-zhi",
       "martial-cognize"
     ]},
    {"朱丹臣", "dali:shufang", "透骨钉", ["dagger", "qingliang-daxuefa", "martial-cognize"]}
  ]

  setup_all do
    %{world: Loader.load()}
  end

  defp config(world, name, room, key) do
    npc =
      Enum.find(world.characters, fn character ->
        character.name == name and character.room_id == room
      end) || raise("#{name} not found at #{room}")

    npc.meta.inquiries[key] || raise("#{name}/#{key} inquiry not found")
  end

  test "14 条段氏授艺的 improve_skills 与 LPC improve_skill 调用逐项一致", %{world: world} do
    for {name, room, key, expected} <- @grants do
      cfg = config(world, name, room, key)

      assert cfg["kind"] == "sect_master_grant", "#{name}/#{key} kind"
      assert cfg["improve_skills"] == expected, "#{name}/#{key} improve_skills"
    end
  end

  test "段正明三条一阳指绝招恢复 force 首提升与 LPC 原顺序", %{world: world} do
    for key <- ["一指乾坤", "神指点穴", "起死回生"] do
      cfg = config(world, "段正明", "dali:qiandian", key)

      assert hd(cfg["improve_skills"]) == "force", "#{key} 应以 force 起手"

      assert cfg["improve_skills"] == [
               "force",
               "jingluo-xue",
               "finger",
               "yiyang-zhi",
               "martial-cognize"
             ]
    end
  end

  test "一灯两招保留重复 improve 次数，不被折叠为单次", %{world: world} do
    jian = config(world, "一灯大师", "dali:qingchi", "先天功乾阳剑气")["improve_skills"]

    assert Enum.count(jian, &(&1 == "force")) == 3
    assert Enum.count(jian, &(&1 == "finger")) == 3
    assert Enum.count(jian, &(&1 == "xiantian-gong")) == 2
    assert Enum.count(jian, &(&1 == "yiyang-zhi")) == 2
    assert length(jian) == 11

    die = config(world, "一灯大师", "dali:qingchi", "阳关三叠")["improve_skills"]

    assert Enum.count(die, &(&1 == "force")) == 3
    assert Enum.count(die, &(&1 == "jingluo-xue")) == 3
    assert Enum.count(die, &(&1 == "finger")) == 3
    assert Enum.count(die, &(&1 == "yiyang-zhi")) == 3
    assert length(die) == 13
  end
end
