# frozen_string_literal: true

class AddAssembledToContigs < ActiveRecord::Migration
  def change
    add_column :contigs, :assembled, :boolean
  end
end
