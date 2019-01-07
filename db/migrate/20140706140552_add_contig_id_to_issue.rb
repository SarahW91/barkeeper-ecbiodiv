# frozen_string_literal: true

class AddContigIdToIssue < ActiveRecord::Migration
  def change
    add_column :issues, :contig_id, :integer
  end
end
