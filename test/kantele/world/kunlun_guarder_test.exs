defmodule Kantele.World.KunlunGuarderTest do
  @moduledoc """
  昆仑派 guarder / coagent 回填定向测试（Task #757）。

  数据来源：LPC `kungfu/class/kunlun/{banshuxian,xihuazi,hetaichong}.c`：
    1. 班淑娴、西华子 `inherit F_GUARDER` + `set("guarder", ...)`
       的 refuse_other / refuse_carry 逐字文案（family = 昆仑派）；
    2. 两者 `set("coagents", ({ ["startroom":"/d/kunlun/tieqinju", "id":"he taichong"] }))`
       指向何太冲，startroom = kunlun:tieqinju；
    3. 占位符 `$N`/`$n` 已在 loader 归一为 `{npc}`/`{name}`，不得字面残留；
    4. 何太冲 `inherit F_COAGENT` —— 引擎 `Coagent.start_help/1` 已存，
       本测试锁定其可被召唤的决策语义（同房间就地开打 / 异地移动）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Npc.Coagent
  alias Kantele.World.Loader

  setup_all do
    %{world: Loader.load()}
  end

  defp npc(world, alias_key) do
    Enum.find(world.characters, fn c ->
      Enum.any?(c.meta.aliases || [], &(&1 == alias_key))
    end)
  end

  # ---------- 1. 班淑娴 guarder ----------

  describe "班淑娴 guarder（LPC banshuxian.c F_GUARDER）" do
    test "meta.guarder family=昆仑派 + 两句逐字拒绝台词", %{world: world} do
      guarder = npc(world, "kunlun_banshuxian").meta.guarder

      assert guarder != nil
      assert guarder.family == "昆仑派"

      assert guarder.msgs.refuse_other ==
               "{npc}对{name}冷喝道：你给我站住！我们昆仑派岂是由得外人随便走动地方？"

      assert guarder.msgs.refuse_carry ==
               "{npc}对{name}喝道：你背上背的是什么人？给我放下来！"
    end

    test "拒绝文案无字面 $N/$n 残留", %{world: world} do
      guarder = npc(world, "kunlun_banshuxian").meta.guarder
      refute Enum.any?(Map.values(guarder.msgs), &String.contains?(&1, "$N"))
      refute Enum.any?(Map.values(guarder.msgs), &String.contains?(&1, "$n"))
    end
  end

  # ---------- 2. 西华子 guarder ----------

  describe "西华子 guarder（LPC xihuazi.c F_GUARDER）" do
    test "meta.guarder family=昆仑派 + 两句逐字拒绝台词", %{world: world} do
      guarder = npc(world, "kunlun_xihuazi").meta.guarder

      assert guarder != nil
      assert guarder.family == "昆仑派"

      assert guarder.msgs.refuse_other ==
               "{npc}对{name}怒喝道：他奶奶的，你是什么人？昆仑派岂是让你随便走动地方？"

      assert guarder.msgs.refuse_carry ==
               "{npc}对{name}喝道：你背上背的是什么人？给我放下来！"
    end

    test "拒绝文案无字面 $N/$n 残留", %{world: world} do
      guarder = npc(world, "kunlun_xihuazi").meta.guarder
      refute Enum.any?(Map.values(guarder.msgs), &String.contains?(&1, "$N"))
      refute Enum.any?(Map.values(guarder.msgs), &String.contains?(&1, "$n"))
    end
  end

  # ---------- 3. coagents ----------

  describe "coagents 指向何太冲（LPC set(\"coagents\")）" do
    for npc_key <- ["kunlun_banshuxian", "kunlun_xihuazi"] do
      test "#{npc_key} coagents = [he taichong @ kunlun:tieqinju]", %{world: world} do
        coagents = npc(world, unquote(npc_key)).meta.coagents

        assert is_list(coagents)
        assert length(coagents) == 1

        [co] = coagents
        assert Map.get(co, "id") == "he taichong"
        assert Map.get(co, "startroom") == "kunlun:tieqinju"
      end
    end
  end

  # ---------- 4. 何太冲 F_COAGENT 决策语义 ----------

  describe "何太冲 F_COAGENT（引擎 Coagent.start_help/1）" do
    test "同房间未杀该目标 → 就地开打" do
      assert Coagent.start_help(%{
               in_target_room?: true,
               already_killing?: false,
               helping?: false,
               fighting?: false,
               target_room: "kunlun:qianting",
               target_id: "enemy:1",
               living?: true
             }) == {:fight, "enemy:1"}
    end

    test "异地且未在战斗/助战 → 移动后参战" do
      assert Coagent.start_help(%{
               in_target_room?: false,
               already_killing?: false,
               helping?: false,
               fighting?: false,
               target_room: "kunlun:sanshengtang",
               target_id: "enemy:2",
               living?: true
             }) == {:move, "kunlun:sanshengtang", "enemy:2"}
    end

    test "已在助战或战斗中 → 不再出动" do
      base = %{
        in_target_room?: false,
        already_killing?: false,
        helping?: false,
        fighting?: false,
        target_room: "kunlun:qianting",
        target_id: "enemy:3",
        living?: true
      }

      assert Coagent.start_help(%{base | helping?: true}) == {:noop}
      assert Coagent.start_help(%{base | fighting?: true}) == {:noop}
    end
  end
end
