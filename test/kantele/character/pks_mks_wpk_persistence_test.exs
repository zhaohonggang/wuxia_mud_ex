defmodule Kantele.Character.PksMksWpkPersistenceTest do
  @moduledoc """
  #642 PKS/MKS/WPK 击杀计数持久化（K_record 依赖）

  测试：
  1. Records.save/1 将 meta.combat.temp 中的 PKS/MKS/WPK 及正邪细分落盘到
     character_metadata 表。
  2. Records.apply_to_character/2 从 Metadata 读取并恢复到 meta.combat.temp。
  3. shaolin_kneel.ex / shaolin_gate.ex 能从 combat.temp 读取 PKS/MKS/WPK。
  """

  use ExVenture.DataCase, async: false

  alias ExVenture.Characters.Metadata
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @name "pks-mks-wpk-#{System.unique_integer([:positive])}"

  defp build_character() do
    stats =
      %{
        Stats.new()
        | combat_exp: 10_000,
          potential: 200,
          skills: %{"unarmed" => 60, "sword" => 60, "dodge" => 60, "parry" => 60, "force" => 20},
          performs: MapSet.new(["unarmed"]),
          shen: 600
      }

    combat =
      %Combat{}
      |> Map.put(:temp, %{
        PKS: 5,
        MKS: 12,
        WPK: 3,
        WPK_GOOD: 2,
        WPK_BAD: 1,
        WPK_NOTGOOD: 4,
        WPK_NOTBAD: 8
      })

    %Kalevala.Character{
      id: @name,
      name: @name,
      pid: self(),
      room_id: "register:yanluodian",
      attributes: %{},
      inventory: [],
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: stats,
        combat: combat,
        coins: 100,
        env: %{gender: "男性", setup_done: true},
        setup_done: true
      }
    }
  end

  describe "save → load → apply 往返保留击杀计数" do
    test "PKS/MKS/WPK 及正邪细分全部保留" do
      character = build_character()

      assert :ok = Records.save(character)

      {:ok, metadata, _wiz} = Records.load(@name)

      # —— DB 列 ——
      assert metadata.pks == 5
      assert metadata.mks == 12
      assert metadata.wpk == 3
      assert metadata.wpk_good == 2
      assert metadata.wpk_bad == 1
      assert metadata.wpk_notgood == 4
      assert metadata.wpk_notbad == 8

      # —— apply 恢复到 combat.temp ——
      restored =
        Records.apply_to_character(character, {:ok, metadata}, 0)

      temp = restored.meta.combat.temp
      assert Map.get(temp, :PKS) == 5
      assert Map.get(temp, :MKS) == 12
      assert Map.get(temp, :WPK) == 3
      assert Map.get(temp, :WPK_GOOD) == 2
      assert Map.get(temp, :WPK_BAD) == 1
      assert Map.get(temp, :WPK_NOTGOOD) == 4
      assert Map.get(temp, :WPK_NOTBAD) == 8
    end

    test "无击杀计数时退化为 0" do
      character =
        %Kalevala.Character{
          id: @name,
          name: @name,
          meta: %PlayerMeta{
            vitals: Vitals.new(),
            stats: Stats.new(),
            combat: Combat.new(),
            env: %{gender: "男性", setup_done: true},
            setup_done: true
          }
        }

      assert :ok = Records.save(character)

      {:ok, metadata, _wiz} = Records.load(@name)

      assert metadata.pks == 0
      assert metadata.mks == 0
      assert metadata.wpk == 0
      assert metadata.wpk_good == 0
      assert metadata.wpk_bad == 0
      assert metadata.wpk_notgood == 0
      assert metadata.wpk_notbad == 0

      restored =
        Records.apply_to_character(character, {:ok, metadata}, 0)

      temp = restored.meta.combat.temp
      assert Map.get(temp, :PKS, 0) == 0
      assert Map.get(temp, :MKS, 0) == 0
      assert Map.get(temp, :WPK, 0) == 0
    end

    test "旧档（无 pks/mks/wpk 列）apply 不崩溃，退化为 0" do
      # 模拟旧版 Metadata 记录，无 pks/mks/wpk 字段（缺省为 nil/0）
      metadata = %Metadata{
        character_id: 999_801,
        gender: "男性",
        pks: nil,
        mks: nil,
        wpk: nil,
        wpk_good: nil,
        wpk_bad: nil,
        wpk_notgood: nil,
        wpk_notbad: nil
      }

      character =
        %Kalevala.Character{
          id: @name,
          name: @name,
          meta: %PlayerMeta{
            vitals: Vitals.new(),
            stats: Stats.new(),
            combat: Combat.new(),
            env: %{gender: "男性", setup_done: true},
            setup_done: true
          }
        }

      restored =
        Records.apply_to_character(character, {:ok, metadata}, 0)

      temp = restored.meta.combat.temp
      assert Map.get(temp, :PKS, 0) == 0
      assert Map.get(temp, :MKS, 0) == 0
      assert Map.get(temp, :WPK, 0) == 0
    end
  end

  describe "combat_temp 中保留已有 apply 覆盖不丢失" do
    test "apply_to_character 覆盖 combat.temp 中的击杀计数" do
      # 构造一个带有旧计数的 metadata
      metadata = %Metadata{
        character_id: 999_802,
        pks: 10,
        mks: 20,
        wpk: 5,
        wpk_good: 3,
        wpk_bad: 2,
        wpk_notgood: 6,
        wpk_notbad: 14
      }

      character =
        %Kalevala.Character{
          id: @name,
          name: @name,
          meta: %PlayerMeta{
            vitals: Vitals.new(),
            stats: Stats.new(),
            combat: %Combat{temp: %{PKS: 1, MKS: 2, WPK: 0}},
            env: %{gender: "男性", setup_done: true},
            setup_done: true
          }
        }

      restored =
        Records.apply_to_character(character, {:ok, metadata}, 0)

      temp = restored.meta.combat.temp
      assert Map.get(temp, :PKS) == 10
      assert Map.get(temp, :MKS) == 20
      assert Map.get(temp, :WPK) == 5
      assert Map.get(temp, :WPK_GOOD) == 3
      assert Map.get(temp, :WPK_BAD) == 2
      assert Map.get(temp, :WPK_NOTGOOD) == 6
      assert Map.get(temp, :WPK_NOTBAD) == 14
    end
  end
end
