defmodule Kantele.World.XiaoyaoGuarderTest do
  @moduledoc """
  逍遥派 #809 coagents / #810 苏星河自定义 permit_pass 定向测试。

  LPC 依据：
    - `kungfu/class/xiaoyao/goudu.c:62-67` → 康广陵 @ muwu1 / 薛慕华 @ muwu2
    - `kungfu/class/xiaoyao/suxingh.c:99-102` → 无崖子 @ shishi
    - `kungfu/class/xiaoyao/suxingh.c:104-111` → guarder 两句逐字拒绝
    - `kungfu/class/xiaoyao/suxingh.c:156-179` → master_id 直放 → exp → 心法 → sigh/say
    - `d/xiaoyao/qingcaop.c:31-44` → 仅 "in" 方向调用 permit_pass
  """

  use ExUnit.Case, async: true

  alias Kantele.Npc.Guarder
  alias Kantele.World.Loader

  setup_all do
    %{world: Loader.load()}
  end

  defp npc(world, alias_key) do
    Enum.find(world.characters, fn c ->
      Enum.any?(c.meta.aliases || [], &(&1 == alias_key))
    end)
  end

  describe "#809 coagents（LPC set(\"coagents\")）" do
    test "苟读：康广陵 @ xiaoyao:muwu1 + 薛慕华 @ xiaoyao:muwu2", %{world: world} do
      coagents = npc(world, "gou du").meta.coagents

      assert is_list(coagents)
      assert length(coagents) == 2

      assert Enum.map(coagents, &Map.get(&1, "id")) == [
               "kang guangling",
               "xue muhua"
             ]

      assert Enum.map(coagents, &Map.get(&1, "startroom")) == [
               "xiaoyao:muwu1",
               "xiaoyao:muwu2"
             ]
    end

    test "苏星河：无崖子 @ xiaoyao:shishi", %{world: world} do
      coagents = npc(world, "su xinghe").meta.coagents

      assert is_list(coagents)
      assert length(coagents) == 1
      assert Map.get(hd(coagents), "id") == "wuya zi"
      assert Map.get(hd(coagents), "startroom") == "xiaoyao:shishi"
    end
  end

  describe "#810 guarder 数据与房间方向" do
    test "苏星河 guarder 配置含自定义门与 sigh/say 台词", %{world: world} do
      guarder = npc(world, "su xinghe").meta.guarder

      assert guarder.family == "逍遥派"
      assert guarder.allow_master_ids == ["wuya zi"]
      assert guarder.min_exp == 300000
      assert guarder.min_skills == %{"xiaoyao_xinfa" => 120}

      assert guarder.msgs.refuse_other ==
               "{npc}对{name}冷喝道：阁下请留步，此处乃本门禁地，旁人不得入内。"

      assert guarder.msgs.refuse_carry ==
               "{npc}对{name}喝道：你背负的是什么人，还不快快给我放下！"

      assert guarder.msgs.refuse_exp ==
               "{npc}对{name}说道：你这种身手不要去那里，好好学我们逍遥派武功。"

      assert guarder.msgs.refuse_skill ==
               "{npc}对{name}说道：连我们逍遥心法都学不好，乱走什么？"

      assert guarder.msgs.pass == [
               "{npc}叹了口气。",
               "{npc}对{name}说道：去吧，去吧！有缘者事竟成。"
             ]

      refute Enum.any?(Map.values(guarder.msgs), fn
        text when is_binary(text) -> String.contains?(text, "$N") or String.contains?(text, "$n")
        texts when is_list(texts) ->
          Enum.any?(texts, &String.contains?(&1, "$N") or String.contains?(&1, "$n"))

        _ ->
          false
      end)
    end

    test "青草坪仅 in 方向盘查（qingcaop.c:35）", %{world: world} do
      room = Enum.find(world.rooms, &(&1.id == "xiaoyao:qingcaop"))

      assert room.behavior == "guarded_exit"
      assert room.behavior_config.guard_directions == ["in"]
      assert room.behavior_config.guard_npc == "su xinghe"
    end
  end

  describe "#810 Guarder.permit_pass 门序" do
    defp opts(overrides \\ %{}) do
      Map.merge(
        %{
          living?: true,
          my_family: "逍遥派",
          guest_family: "逍遥派",
          guest_born_family: "逍遥派",
          carried_families: [],
          guest_master_id: "some one",
          guest_exp: 400_000,
          guest_skill_levels: %{"xiaoyao-xinfa" => 130},
          msgs: %{
            refuse_exp: "EXP_DENY",
            refuse_skill: "SKILL_DENY",
            pass: ["PASS_ONE", "PASS_TWO"]
          },
          allow_master_ids: ["wuya zi"],
          min_exp: 300_000,
          min_skills: %{"xiaoyao_xinfa" => 120}
        },
        overrides
      )
    end

    test "无崖子亲传：跳过经验/心法门并广播台词" do
      assert Guarder.permit_pass(opts(%{guest_master_id: "wuya zi", guest_exp: 0})) ==
               {:allow, ["PASS_ONE", "PASS_TWO"]}
    end

    test "经验不足：先于心法门拒绝" do
      assert Guarder.permit_pass(
               opts(%{
                 guest_exp: 100_000,
                 guest_skill_levels: %{"xiaoyao-xinfa" => 0}
               })
             ) == {:deny, "EXP_DENY"}
    end

    test "经验够但心法不足：心法门拒绝" do
      assert Guarder.permit_pass(opts(%{guest_skill_levels: %{"xiaoyao-xinfa" => 119}})) ==
               {:deny, "SKILL_DENY"}
    end

    test "两门均过：allow + 两句台词" do
      assert Guarder.permit_pass(opts()) == {:allow, ["PASS_ONE", "PASS_TWO"]}
    end

    test "外派仍按基础 guarder 拒绝（且优先于自定义门）" do
      assert Guarder.permit_pass(
               opts(%{
                 guest_family: "星宿派",
                 guest_born_family: "星宿派",
                 guest_exp: 0,
                 msgs: %{refuse_other: "OTHER_DENY", pass: ["PASS_ONE"]}
               })
             ) == {:deny, "OTHER_DENY"}
    end

    test "背负他派：按 refuse_carry 拒绝" do
      assert Guarder.permit_pass(
               opts(%{
                 carried_families: ["星宿派"],
                 msgs: %{refuse_carry: "CARRY_DENY"}
               })
             ) == {:deny, "CARRY_DENY"}
    end

    test "旧调用方未配置新字段时仍返回裸 {:allow}" do
      assert Guarder.permit_pass(%{
               living?: true,
               my_family: "逍遥派",
               guest_family: "逍遥派",
               guest_born_family: "逍遥派",
               carried_families: [],
               msgs: %{}
             }) == {:allow}
    end
  end
end
