defmodule Kantele.World.ZhenyuanGuarderCoagentsTest do
  @moduledoc """
  镇远镖局 #836 守卫与助战回填定向测试。

  LPC 依据：
    - `kungfu/class/zhenyuan/tongzhaohe.c:56-67` → 王维扬 @ beijing:shufang
      助战 + 童兆和两句 F_GUARDER 拒绝文案；
    - `kungfu/class/zhenyuan/wangjianjie.c:82-94` → 王维扬 @ beijing:shufang
      助战 + 王剑杰两句 F_GUARDER 拒绝文案；
    - `d/beijing/gate.c:26-35` → 仅 `in` 方向、童兆和在场时 permit_pass；
    - `d/beijing/zhengting.c:28-39` → 仅 north/east/west、王剑杰在场时 permit_pass。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Event
  alias Kalevala.Event.Movement
  alias Kalevala.World.Room.Context
  alias Kantele.Npc.Guarder
  alias Kantele.World.Loader

  @handler Kalevala.World.Room.Callbacks.Kantele.World.Room

  @tong_refuse_other "{npc}对{name}皱眉道：喂！你这倒是往哪里走啊？"
  @tong_refuse_carry "{npc}对{name}嬉皮笑脸地道：你背上背的是个啥？扔下来给咱瞧瞧。"
  @wang_refuse_other "{npc}对{name}冷喝道：我不管你是怎么进来的，但是请你马上离开，否则休怪我无情！"
  @wang_refuse_carry "{npc}对着{name}剑眉一竖，喝道：你背上背的是什么？给我放下来！"

  setup_all do
    %{world: Loader.load()}
  end

  defp npc(world, alias_key) do
    case Enum.find(world.characters, fn character ->
           Enum.any?(character.meta.aliases || [], &(&1 == alias_key))
         end) do
      nil -> flunk("world 中找不到别名 #{alias_key} 的 NPC")
      character -> character
    end
  end

  defp room(world, room_id) do
    case Enum.find(world.rooms, &(&1.id == room_id)) do
      nil -> flunk("world 中找不到房间 #{room_id}")
      found -> found
    end
  end

  defp occupants(world, room_id) do
    Enum.filter(world.characters, &(&1.room_id == room_id))
  end

  defp assert_no_lpc_placeholders(guarder) do
    refute Enum.any?(Map.values(guarder.msgs), fn
             text when is_binary(text) ->
               String.contains?(text, "$N") or String.contains?(text, "$n")

             texts when is_list(texts) ->
               Enum.any?(texts, fn text ->
                 is_binary(text) and
                   (String.contains?(text, "$N") or String.contains?(text, "$n"))
               end)

             _ ->
               false
           end)
  end

  describe "NPC guarder 数据（F_GUARDER 逐字文案）" do
    test "童兆和：family=八卦门 + 皱眉道/嬉皮笑脸两句", %{world: world} do
      guarder = npc(world, "tong zhaohe").meta.guarder

      assert guarder != nil
      assert guarder.family == "八卦门"
      assert guarder.msgs.refuse_other == @tong_refuse_other
      assert guarder.msgs.refuse_carry == @tong_refuse_carry
      assert_no_lpc_placeholders(guarder)
    end

    test "王剑杰：family=八卦门 + 冷喝道/剑眉一竖两句", %{world: world} do
      guarder = npc(world, "wang jianjie").meta.guarder

      assert guarder != nil
      assert guarder.family == "八卦门"
      assert guarder.msgs.refuse_other == @wang_refuse_other
      assert guarder.msgs.refuse_carry == @wang_refuse_carry
      assert_no_lpc_placeholders(guarder)
    end
  end

  describe "coagents（LPC set(\"coagents\")）" do
    for {alias_key, label} <- [{"tong zhaohe", "童兆和"}, {"wang jianjie", "王剑杰"}] do
      test "#{label}：王维扬 @ beijing:shufang", %{world: world} do
        coagents = npc(world, unquote(alias_key)).meta.coagents

        assert is_list(coagents)
        assert length(coagents) == 1

        [coagent] = coagents
        assert Map.get(coagent, "id") == "wang weiyang"
        assert Map.get(coagent, "startroom") == "beijing:shufang"
      end
    end

    test "coagent 目标王维扬确实位于 beijing:shufang", %{world: world} do
      assert npc(world, "wang weiyang").room_id == "beijing:shufang"
    end
  end

  describe "房间 valid_leave 方向规则" do
    test "beijing:gate 仅 in 方向盘查，交给童兆和", %{world: world} do
      gate = room(world, "beijing:gate")

      assert gate.behavior == "guarded_exit"
      assert gate.behavior_config.guard_npc == "tong zhaohe"
      assert gate.behavior_config.guard_directions == ["in"]
      assert gate.behavior_config.permit_module == "Kantele.Npc.Guarder"
      assert gate.behavior_config.permit_function == "permit_pass"
    end

    test "beijing:zhengting 仅 north/east/west 方向盘查，交给王剑杰", %{world: world} do
      zhengting = room(world, "beijing:zhengting")

      assert zhengting.behavior == "guarded_exit"
      assert zhengting.behavior_config.guard_npc == "wang jianjie"
      assert zhengting.behavior_config.guard_directions == ["north", "east", "west"]
      assert zhengting.behavior_config.permit_module == "Kantele.Npc.Guarder"
      assert zhengting.behavior_config.permit_function == "permit_pass"
    end
  end

  describe "Guarder.permit_pass 使用加载后的逐字文案" do
    defp opts(guarder, overrides \\ %{}) do
      Map.merge(
        %{
          living?: true,
          my_family: guarder.family,
          guest_family: "八卦门",
          guest_born_family: "八卦门",
          carried_families: [],
          msgs: guarder.msgs
        },
        overrides
      )
    end

    test "童兆和：外人命中 refuse_other，背负他派命中 refuse_carry", %{world: world} do
      guarder = npc(world, "tong zhaohe").meta.guarder

      assert Guarder.permit_pass(opts(guarder, %{guest_family: nil, guest_born_family: nil})) ==
               {:deny, @tong_refuse_other}

      assert Guarder.permit_pass(opts(guarder, %{carried_families: ["星宿派"]})) ==
               {:deny, @tong_refuse_carry}
    end

    test "王剑杰：外人命中 refuse_other，背负他派命中 refuse_carry", %{world: world} do
      guarder = npc(world, "wang jianjie").meta.guarder

      assert Guarder.permit_pass(opts(guarder, %{guest_family: nil, guest_born_family: nil})) ==
               {:deny, @wang_refuse_other}

      assert Guarder.permit_pass(opts(guarder, %{carried_families: ["星宿派"]})) ==
               {:deny, @wang_refuse_carry}
    end

    test "同门且未背负他派：放行", %{world: world} do
      for alias_key <- ["tong zhaohe", "wang jianjie"] do
        assert Guarder.permit_pass(opts(npc(world, alias_key).meta.guarder)) == {:allow}
      end
    end
  end

  describe "房间移动拦截实际生效" do
    defp mover(family_name) do
      family =
        if family_name do
          %{name: family_name, born_family: family_name}
        else
          nil
        end

      %{pid: self(), name: "测试玩家", meta: %{family: family, carrying: []}}
    end

    defp move(room, characters, player, dir) do
      room_exit = Enum.find(room.exits, &(&1.exit_name == dir))
      assert room_exit, "#{room.id} 没有 #{dir} 出口"

      event = %Event{
        topic: Movement.Request,
        from_pid: self(),
        data: %Movement.Request{character: player, exit_name: dir}
      }

      context = %Context{
        data: room,
        characters: characters,
        item_instances: [],
        assigns: %{},
        events: [],
        output: []
      }

      @handler.movement_request(room, context, event, room_exit)
    end

    test "gate：外人走 in 被童兆和拦下，south 放行，同门走 in 放行", %{world: world} do
      gate = room(world, "beijing:gate")
      characters = occupants(world, "beijing:gate")

      assert {:abort, _event, {:guarder_denied, msg}} = move(gate, characters, mover(nil), "in")

      # room.ex 带原始 guarder 文案；{npc}/{name} 由 MoveView 在输出层渲染。
      assert msg == @tong_refuse_other

      assert {:proceed, _event, _exit} = move(gate, characters, mover(nil), "south")
      assert {:proceed, _event, _exit} = move(gate, characters, mover("八卦门"), "in")
      assert {:proceed, _event, _exit} = move(gate, [], mover(nil), "in")
    end

    test "zhengting：外人走 north/east/west 被王剑杰拦下，south 放行", %{world: world} do
      zhengting = room(world, "beijing:zhengting")
      characters = occupants(world, "beijing:zhengting")

      for dir <- ["north", "east", "west"] do
        assert {:abort, _event, {:guarder_denied, msg}} =
                 move(zhengting, characters, mover(nil), dir)

        assert msg == @wang_refuse_other
      end

      assert {:proceed, _event, _exit} = move(zhengting, characters, mover(nil), "south")
      assert {:proceed, _event, _exit} = move(zhengting, characters, mover("八卦门"), "north")
      assert {:proceed, _event, _exit} = move(zhengting, [], mover(nil), "north")
    end
  end
end
