class AddIndividualIdToIsolates < ActiveRecord::Migration
  def change
    add_column :isolates, :individual_id, :integer
  end
end
