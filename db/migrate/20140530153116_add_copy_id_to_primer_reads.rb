class AddCopyIdToPrimerReads < ActiveRecord::Migration
  def change
    add_column :primer_reads, :copy_id, :integer
  end
end
