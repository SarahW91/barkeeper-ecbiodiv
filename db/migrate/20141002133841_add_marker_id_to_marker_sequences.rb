class AddMarkerIdToMarkerSequences < ActiveRecord::Migration
  def change
    add_column :marker_sequences, :marker_id, :integer
  end
end
