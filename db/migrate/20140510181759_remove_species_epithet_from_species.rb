class RemoveSpeciesEpithetFromSpecies < ActiveRecord::Migration
  def change
    remove_column :species, :species_epithet, :string
  end
end
