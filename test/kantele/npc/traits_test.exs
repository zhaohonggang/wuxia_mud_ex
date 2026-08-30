defmodule Kantele.Npc.TraitsTest do
  use ExUnit.Case, async: true

  alias Kantele.Npc.Guarder
  alias Kantele.Npc.Coagent
  alias Kantele.Npc.Master
  alias Kantele.Npc.Quester

  describe "Guarder" do
    test "is_guarder?/1" do
      assert Guarder.is_guarder?(%{})
    end

    test "permit_pass: 非存活 -> 放行" do
      assert Guarder.permit_pass(%{
               living?: false,
               my_family: "武当派",
               guest_family: nil,
               guest_born_family: nil,
               carried_families: [],
               msgs: %{}
             }) == {:allow}
    end

    test "permit_pass: 本派弟子放行" do
      assert Guarder.permit_pass(%{
               living?: true,
               my_family: "武当派",
               guest_family: "武当派",
               guest_born_family: "武当",
               carried_families: ["武当派"],
               msgs: %{}
             }) == {:allow}
    end

    test "permit_pass: 外人（非本派）拒绝 refuse_other" do
      assert {:deny, msg} =
               Guarder.permit_pass(%{
                 living?: true,
                 my_family: "武当派",
                 guest_family: "峨嵋派",
                 guest_born_family: "峨嵋",
                 carried_families: [],
                 msgs: %{}
               })

      assert msg =~ "武当派"
    end

    test "permit_pass: 本派弟子（born_family 归属本派）放行" do
      assert Guarder.permit_pass(%{
               living?: true,
               my_family: "武当派",
               guest_family: "武当派",
               guest_born_family: "武当",
               carried_families: ["武当派"],
               msgs: %{}
             }) == {:allow}
    end

    test "permit_pass: 携带他派之人拒绝" do
      assert {:deny, msg} =
               Guarder.permit_pass(%{
                 living?: true,
                 my_family: "武当派",
                 guest_family: "武当派",
                 guest_born_family: "武当",
                 carried_families: ["峨嵋派"],
                 msgs: %{}
               })

      assert msg =~ "背的是谁"
    end

    test "check_enemy: 不同派 fight -> ignore" do
      assert Guarder.check_enemy(%{
               my_family: "武当派",
               enemy_family: "峨嵋派",
               my_name: "张三丰",
               enemy_name: "甲",
               type: "fight"
             }) == {:ignore}
    end

    test "check_enemy: 不同派 kill -> kill" do
      assert Guarder.check_enemy(%{
               my_family: "武当派",
               enemy_family: "峨嵋派",
               my_name: "张三丰",
               enemy_name: "甲",
               enemy_id: "jia",
               type: "kill"
             }) == {:kill, "jia"}
    end

    test "check_enemy: 本派 kill 同门 -> kill" do
      assert Guarder.check_enemy(%{
               my_family: "武当派",
               enemy_family: "武当派",
               my_name: "张三丰",
               enemy_name: "甲",
               enemy_id: "jia",
               type: "kill"
             }) == {:kill, "jia"}
    end
  end

  describe "Coagent" do
    test "is_coagent?/is_helping?" do
      assert Coagent.is_coagent?(%{})
      assert Coagent.is_helping?(true)
      refute Coagent.is_helping?(false)
    end

    test "start_help: 已在目标房间已在杀 -> already" do
      assert Coagent.start_help(%{
               in_target_room?: true,
               already_killing?: true,
               helping?: false,
               fighting?: false,
               target_room: "r",
               target_id: "x",
               living?: true
             }) == {:already}
    end

    test "start_help: 异地且未在助战 -> move" do
      assert Coagent.start_help(%{
               in_target_room?: false,
               already_killing?: false,
               helping?: false,
               fighting?: false,
               target_room: "r",
               target_id: "x",
               living?: true
             }) == {:move, "r", "x"}
    end

    test "start_help: 正在助战 -> noop" do
      assert Coagent.start_help(%{
               in_target_room?: false,
               already_killing?: false,
               helping?: true,
               fighting?: false,
               target_room: "r",
               target_id: "x",
               living?: true
             }) == {:noop}
    end

    test "start_help: 不存活 -> noop" do
      assert Coagent.start_help(%{
               in_target_room?: false,
               already_killing?: false,
               helping?: false,
               fighting?: false,
               target_room: "r",
               target_id: "x",
               living?: false
             }) == {:noop}
    end

    test "finish_help: 回到 startroom" do
      assert Coagent.finish_help("start", "current") == {:return, "start"}
      assert Coagent.finish_help("start", "start") == {:stay}
      assert Coagent.finish_help("", "current") == {:stay}
    end
  end

  describe "Master" do
    test "prevent_learn: 非嫡传同门派 -> true" do
      my = %{name: "武当派", master_id: "zs", master_name: "张三丰"}
      my2 = my |> Map.put(:master_id, "b")
      assert Master.prevent_learn?(my, my, my2)
    end

    test "prevent_learn: 嫡传 -> false" do
      my = %{name: "武当派", master_id: "zs", master_name: "张三丰"}
      disciple = %{name: "武当派", master_id: "zs", master_name: "张三丰", generation: 1}
      refute Master.prevent_learn?(my, my, disciple)
    end

    test "attempt_detach: 非我弟子 -> noop" do
      my = %{name: "武当派"}
      other = %{name: "峨嵋派"}
      assert Master.attempt_detach(my, other, nil) == {:noop}
    end

    test "attempt_detach: 叛师 loss => penalty true" do
      my = %{name: "武当派", master_id: "zs", master_name: "张三丰"}
      disciple = %{name: "武当派", master_id: "zs", master_name: "张三丰", generation: 1}
      assert Master.attempt_detach(my, disciple, nil) == {:detach, %{penalty?: true}}
    end

    test "attempt_detach: 转世脱离一次 => penalty false" do
      my = %{name: "武当派", master_id: "zs", master_name: "张三丰"}
      disciple = %{name: "武当派", master_id: "zs", master_name: "张三丰", generation: 1}
      assert Master.attempt_detach(my, disciple, "武当派") == {:detach, %{penalty?: false}}
    end
  end

  describe "Quester" do
    test "is_quester?/1" do
      assert Quester.is_quester?(%{})
    end

    test "ask_quest/cancel_quest 无任务配置返回友好文案" do
      assert Quester.ask_quest(%{}, %{}) == {:error, "老朽手头暂无任务可托付。"}
      assert Quester.cancel_quest(%{}, %{}) == {:error, "老朽手头暂无你的任务可作罢。"}
    end
  end
end
