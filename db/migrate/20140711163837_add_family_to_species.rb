class AddFamilyToSpecies < ActiveRecord::Migration
  def change
    add_column :species, :family_id, :integer
  end
end
