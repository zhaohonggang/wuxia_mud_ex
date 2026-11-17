defmodule ExVenture.Repo.Migrations.AddPksMksWpkToCharacterMetadata do
  use Ecto.Migration

  def up do
    alter table(:character_metadata) do
      # PKS：杀害的玩家数目（对应 LPC combatd.c combat/PKS）
      add(:pks, :integer, default: 0)
      # MKS：杀死的 NPC 数目（对应 LPC combatd.c combat/MKS）
      add(:mks, :integer, default: 0)
      # WPK：主动杀死玩家的次数（对应 LPC combatd.c combat/WPK）
      add(:wpk, :integer, default: 0)
      # WPK_GOOD：主动杀死正派玩家的次数（shen > 500）
      add(:wpk_good, :integer, default: 0)
      # WPK_BAD：主动杀死邪派玩家的次数（shen < -500）
      add(:wpk_bad, :integer, default: 0)
      # WPK_NOTGOOD：主动杀死非正派玩家的次数（shen < 500）
      add(:wpk_notgood, :integer, default: 0)
      # WPK_NOTBAD：主动杀死非邪派玩家的次数（shen > -500）
      add(:wpk_notbad, :integer, default: 0)
    end
  end

  def down do
    alter table(:character_metadata) do
      remove(:pks)
      remove(:mks)
      remove(:wpk)
      remove(:wpk_good)
      remove(:wpk_bad)
      remove(:wpk_notgood)
      remove(:wpk_notbad)
    end
  end
end
