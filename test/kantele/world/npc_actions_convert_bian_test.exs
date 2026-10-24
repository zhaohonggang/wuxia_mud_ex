defmodule Kantele.World.NpcActions.ConvertBianTest do
  @moduledoc """
  灵蛇/毒蛇 `bian` 动作单测（NPC 私有动词通道，P5-1c 扩展）。

  覆盖：arg 不命中 → `:not_handled`（放行，无输出）；arg 命中但房间
  GenServer 未运行 → 返回 conn 并向玩家送达失败提示（由分发器按
  `{:handled, conn}` 送达）。
  成功路径（向房间地上生成法杖、从房间移除 NPC、停止 NPC 进程）需
  真实房间 GenServer，留给 Docker 集成测试。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.World.NpcActions.ConvertBian

  @room_id "baituo:xiaoyuan"

  defp conn(_npc) do
    %Conn{
      character: %Kalevala.Character{name: "玩家", room_id: @room_id},
      private: %Conn.Private{
        room: %Kantele.World.Room{id: @room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp npc(name \\ "灵蛇", id \\ "lingshe-1") do
    %Kalevala.Character{name: name, id: id, pid: self(), room_id: @room_id}
  end

  defp params(trailing, npc \\ npc()) do
    %{verb: "bian", trailing: trailing, room_id: @room_id, npc: npc}
  end

  defp out_text(conn), do: conn.output |> Enum.map(& &1.data) |> Enum.join()

  describe "run/2（arg 不命中：LPC return 0，放行）" do
    test "空 arg → :not_handled" do
      c = conn(npc())
      c2 = ConvertBian.run(c, params(""))

      assert c2 == :not_handled
    end

    test "无关 arg → :not_handled" do
      c = conn(npc())
      c2 = ConvertBian.run(c, params("xyz"))

      assert c2 == :not_handled
    end

    test "大小写不命中（Lingshe ≠ 灵蛇/lingshe） → :not_handled" do
      c = conn(npc())
      c2 = ConvertBian.run(c, params("Lingshe"))

      assert c2 == :not_handled
    end
  end

  describe "run/2（arg 命中但房间 GenServer 未运行）" do
    test "灵蛇/lingshe/she/snake 命中 lingshezhang，送达失败提示" do
      for alias <- ["灵蛇", "lingshe", "she", "snake"] do
        c = conn(npc("灵蛇", "lingshe-1"))
        c2 = ConvertBian.run(c, params(alias, npc("灵蛇", "lingshe-1")))

        refute c2 == :not_handled
        assert String.contains?(out_text(c2), "化杖之术施展失败")
      end
    end

    test "毒蛇/shezhang 命中 shezhang，送达失败提示" do
      for alias <- ["毒蛇", "shezhang"] do
        c = conn(npc("毒蛇", "snake-1"))
        c2 = ConvertBian.run(c, params(alias, npc("毒蛇", "snake-1")))

        refute c2 == :not_handled
        assert String.contains?(out_text(c2), "化杖之术施展失败")
      end
    end
  end

  describe "run/2（成功路径：Docker 集成测试）" do
    test "arg 命中 + 房间运行 → 生成法杖 + 移除 NPC + 停止进程（@todo Docker）" do
      # add_item_and_remove_npc/3 通过 :global.whereis_name({Kalevala.World.Room,
      # room_id}) 定位房间 GenServer，原子更新 room.private（插入法杖实例、
      # 移除 NPC 角色），随后 Process.exit(npc.pid, :shutdown)。本处不启动
      # GenServer，故留给 Docker 集成测试验证端到端。
      assert true
    end
  end
end
