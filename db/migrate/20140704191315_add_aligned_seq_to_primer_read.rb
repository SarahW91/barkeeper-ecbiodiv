class AddAlignedSeqToPrimerRead < ActiveRecord::Migration
  def change
    add_column :primer_reads, :aligned_seq, :string
  end
end
