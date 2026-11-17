defmodule Kantele.World.ShaolinApprenticeDialogueTest do
  use ExUnit.Case, async: true

  alias Kantele.World.ShaolinApprenticeDialogue, as: Dialogue

  test "qing.h generation==0 直收文案" do
    apprentice = %{master_generation: 40, allow_zero_generation: true}

    assert Dialogue.lines(apprentice, "清无", "张三", "张三", 0) == [
             {:say, "阿弥陀佛！贫僧就收下你做我的弟子了。"}
           ]
  end

  test "qing.h 直收文案带师父名" do
    apprentice = %{master_generation: 40, allow_zero_generation: true}

    assert Dialogue.lines(apprentice, "清无", "张三", "张三", 41) == [
             {:say, "清无的徒弟怎麽跑到我这儿来了，哈哈哈！"}
           ]
  end

  test "dao.h 直收与越级文案保留原版半角叹号" do
    apprentice = %{
      master_generation: 39,
      rename_prefix: "清",
      direct_name_prefix: "清"
    }

    assert Dialogue.lines(apprentice, "道尘", "清空", "清空", 40) == [
             {:say, "道尘的徒弟怎麽跑到我这儿来了，哈哈哈！"}
           ]

    assert Dialogue.lines(apprentice, "道尘", "清空", "清澄", 41) == [
             {:say, "是道尘叫你来找我的吧，哈哈哈 !"},
             {:say, "贫僧又得一可塑之才，真是可喜可贺 !"},
             {:say, "从今以后你的法名叫做清澄，恭喜你荣升为少林派清字辈弟子 !"}
           ]
  end

  test "hui.h 与 cheng.h 的字辈标题不同" do
    hui = %{master_generation: 38, rename_prefix: "道", direct_name_prefix: "道"}

    assert Dialogue.lines(hui, "慧师", "道远", "道澄", 39) == [
             {:say, "慧师的徒弟怎麽跑到我这儿来了，哈哈哈！"}
           ]

    assert Dialogue.lines(hui, "慧师", "道远", "道澄", 40) == [
             {:say, "是慧师叫你来找我的吧，哈哈哈 !"},
             {:say, "贫僧又得一可塑之才，真是可喜可贺 !"},
             {:say, "从今以后你的法名叫做道澄，恭喜你荣升为少林派道字辈弟子 !"}
           ]

    cheng = %{master_generation: 37, rename_prefix: "慧", direct_name_prefix: "慧"}

    assert Dialogue.lines(cheng, "澄师", "慧远", "慧澄", 39) == [
             {:say, "是澄师叫你来找我的吧，哈哈哈 !"},
             {:say, "贫僧又得一可塑之才，真是可喜可贺 !"},
             {:say, "从今以后你的法名叫做慧澄，恭喜你荣升为少林派慧字辈弟子 !"}
           ]
  end

  test "xuan.h 全角叹号与澄字辈标题" do
    apprentice = %{master_generation: 36, rename_prefix: "澄", allow_luohan_winner: true}

    assert Dialogue.lines(apprentice, "玄悲", "慧远", "澄远", 38) == [
             {:say, "是玄悲叫你来找我的吧，哈哈哈！"},
             {:say, "贫僧又得一可塑之才，真是可喜可贺！"},
             {:say, "从今以后你的法名叫做澄远，恭喜你荣升为少林派澄字辈弟子！"}
           ]
  end

  test "du.h 金刚伏魔圈路线文案" do
    apprentice = %{master_generation: 35, rename_prefix: "玄", require_fumoquan: true}

    assert Dialogue.lines(apprentice, "渡劫", "澄远", "玄远", 37) == [
             {:say, "你能过金刚伏魔圈，哈哈哈！"},
             {:say, "贫僧又得一可塑之才，可喜可贺！"},
             {:say, "从今以后你的法名叫做玄远！"}
           ]
  end

  test "达摩沿用 char + say 两句" do
    apprentice = %{rename_prefix: "渡", rename_index: 1}

    assert Dialogue.lines(apprentice, "达摩老祖", "张三", "渡三", 37) == [
             {:char, "老衲又得一可塑之才，真是大畅老怀 !"},
             {:say, "从今以后你的法名叫做渡三。"}
           ]
  end

  test "UCL 文案可覆写默认台词" do
    apprentice = %{
      master_generation: 35,
      rename_prefix: "玄",
      promotion_msg_1: "自定义第一句 %master%",
      promotion_msg_2: "自定义第二句",
      promotion_msg_3: "自定义第三句 %new_name%"
    }

    assert Dialogue.lines(apprentice, "渡劫", "澄远", "玄远", 37) == [
             {:say, "自定义第一句 渡劫"},
             {:say, "自定义第二句"},
             {:say, "自定义第三句 玄远"}
           ]
  end

  test "非少林配置不产生广播" do
    assert Dialogue.lines(%{family: "华山派"}, "师父", "张三", "张三", 0) == []
  end
end
