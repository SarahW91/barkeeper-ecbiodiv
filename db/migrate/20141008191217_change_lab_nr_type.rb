# frozen_string_literal: true

class ChangeLabNrType < ActiveRecord::Migration
  def change
    change_column :isolates, :lab_nr, :string
  end
end
