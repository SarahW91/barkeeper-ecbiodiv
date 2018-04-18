class CreateJoinTableFreezerProject < ActiveRecord::Migration[5.0]
  def change
    create_join_table :freezers, :projects do |t|
      t.index [:freezer_id, :project_id]
    end
  end
end