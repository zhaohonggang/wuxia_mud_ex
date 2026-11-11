defmodule Kantele.World.ObjectCloneTest do
  use ExUnit.Case, async: false

  alias Kantele.Admin.Security
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.ObjectClone
  alias Kantele.World.ZoneCache

  defp character(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      jingli: Keyword.get(opts, :jingli, 2000),
      neili: Keyword.get(opts, :neili, 9000),
      max_neili: Keyword.get(opts, :max_neili, 10000),
      max_jingli: Keyword.get(opts, :max_jingli, 2000),
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: Keyword.get(opts, :max_qi, 5000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20),
      skills: Keyword.get(opts, :skills, %{}),
      combat_exp: Keyword.get(opts, :combat_exp, 0),
      score: Keyword.get(opts, :score, 0),
      weiwang: Keyword.get(opts, :weiwang, 0)
    }

    combat = Kantele.Character.Combat.new()

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "actor-1"),
      name: Keyword.get(opts, :name, "测试者"),
      pid: self(),
      room_id: Keyword.get(opts, :room_id, "test:room"),
      attributes: Keyword.get(opts, :attributes, %{}),
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  defp wizard_actor() do
    character(id: "wizard-1", name: "巫师", attributes: %{"wiz_level" => 1})
  end

  defp arch_actor() do
    character(id: "arch-1", name: "大巫师", attributes: %{"wiz_level" => 2})
  end

  defp admin_actor() do
    character(id: "admin-1", name: "管理员", attributes: %{"wiz_level" => 3})
  end

  defp mortal_actor() do
    character(id: "mortal-1", name: "平民", attributes: %{"wiz_level" => 0})
  end

  defp setup_zone_cache() do
    case ZoneCache.start_link(id: ZoneCache, name: ZoneCache) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      _ -> :ok
    end

    item = %Kalevala.World.Item{
      id: "clone_lib:arrow",
      name: "羽箭",
      description: "一根细长的箭",
      meta: %{damage: 200, skill_type: "throwing", value: 200, weight: 100, unit: "把"},
      verbs: ["get", "drop"]
    }

    npc = %Kalevala.Character{
      id: "clone_lib:clone_tong_ren",
      name: "铜人",
      description: "一个木制的铜人",
      meta: %{zone_id: "clone_lib"},
      inventory: [],
      attributes: %{}
    }

    zone = %{
      id: "clone_lib",
      name: "标准库",
      items: %{"arrow" => item},
      characters: %{"clone_tong_ren" => npc},
      rooms: %{}
    }

    ZoneCache.put("clone_lib", zone)
  end

  defp cleanup_zone_cache() do
    ZoneCache.delete("clone_lib")
  end

  setup_all do
    Security.ensure!()
    setup_zone_cache()
    on_exit(fn -> cleanup_zone_cache() end)
    :ok
  end

  describe "授权检查" do
    test "平民无 clone 授权时被拒绝" do
      assert match?({:error, :not_authorized},
        ObjectClone.clone_by_path("clone_lib:arrow", 1, mortal_actor()))
    end

    test "巫师可克隆" do
      assert match?({:ok, _}, ObjectClone.clone_by_path("clone_lib:arrow", 1, wizard_actor()))
    end

    test "arch 巫师可克隆" do
      assert match?({:ok, _}, ObjectClone.clone_by_path("clone_lib:arrow", 1, arch_actor()))
    end

    test "admin 可克隆" do
      assert match?({:ok, _}, ObjectClone.clone_by_path("clone_lib:arrow", 1, admin_actor()))
    end

    test "被授予 clone 权限的平民可克隆" do
      Security.grant("平民", "clone")
      assert match?({:ok, _}, ObjectClone.clone_by_path("clone_lib:arrow", 1, mortal_actor()))
      Security.revoke("平民", "clone")
    end
  end

  describe "对象查找" do
    test "按 zone:id 查找 clone_lib 物品" do
      {:ok, %ObjectClone{object: obj}} =
        ObjectClone.clone_by_path("clone_lib:arrow", 1, arch_actor())
      assert obj.item.name == "羽箭"
      assert obj.item.id == "clone_lib:arrow"
    end

    test "查找不存在的对象返回 not_found" do
      assert match?({:error, :not_found},
        ObjectClone.clone_by_path("clone_lib:nonexistent", 1, arch_actor()))
    end

    test "按 NPC 定义查找 clone_tong_ren" do
      {:ok, %ObjectClone{object: obj}} =
        ObjectClone.clone_by_path("clone_lib:clone_tong_ren", 1, arch_actor())
      assert obj.name == "铜人"
    end
  end

  describe "数量设置" do
    test "缺省数量为 1" do
      {:ok, result} = ObjectClone.clone_by_path("clone_lib:arrow", arch_actor())
      assert result.amount == 1
    end

    test "指定数量写入 meta" do
      {:ok, result} = ObjectClone.clone_by_path("clone_lib:arrow", 5, arch_actor())
      assert result.amount == 5
      assert result.object.meta[:amount] == 5
    end

    test "数量为 0 时返回 invalid_args" do
      assert match?({:error, :invalid_args},
        ObjectClone.clone_by_path("clone_lib:arrow", 0, arch_actor()))
    end
  end

  describe "日志记录" do
    test "写入 static/clone/clone.log" do
      log_path = Path.join(["static", "clone", "clone.log"])

      # 清理可能存在的旧日志
      File.rm!(log_path)

      ObjectClone.clone_by_path("clone_lib:arrow", 3, arch_actor())

      assert File.exists?(log_path)
      content = File.read!(log_path)
      assert content =~ "大巫师"
      assert content =~ "clone_lib:arrow"
      assert content =~ "amount=3"

      File.rm!(log_path)
    end
  end

  describe "站点特权" do
    test "admin 站点特权不限制路径" do
      # admin 的 site 为 "gift" 时，非 admin 会被拒绝，但 admin 自己放行
      actor = character(id: "gift-admin", name: "礼物管理员",
        attributes: %{"wiz_level" => 3, "site" => "gift"})
      assert match?({:ok, _},
        ObjectClone.clone_by_path("clone_lib:arrow", 1, actor))
    end

    test "非 admin site=gift 的 /clone/special 路径通过站点特权检查" do
      actor = character(id: "gift-user", name: "礼物用户",
        attributes: %{"wiz_level" => 2, "site" => "gift"})
      result = ObjectClone.clone_by_path("/clone/special/sword.c", 1, actor)
      refute match?({:error, :site_denied}, result)
    end

    test "非 admin site=gift 的非允许路径被拒绝" do
      actor = character(id: "gift-user2", name: "礼物用户2",
        attributes: %{"wiz_level" => 2, "site" => "gift"})
      assert match?({:error, :site_denied},
        ObjectClone.clone_by_path("/clone/weapon/sword.c", 1, actor))
    end
  end
end
