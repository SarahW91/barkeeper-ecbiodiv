# frozen_string_literal: true

class DropSpecEpi < ActiveRecord::Migration
  def change
    drop_table :species_epithets
  end
end
