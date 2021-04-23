require 'rails_helper'
require Rails.root.join "spec/concerns/project_record_spec.rb"

RSpec.describe Individual do
  before(:all) { Project.create(name: 'All') }
  it_behaves_like "project_record"

  subject { FactoryBot.create(:individual) }

  it "is valid with valid attributes" do
    should be_valid
  end

  it "belongs to a species" do
    should belong_to(:species)
  end

  it "belongs to a herbarium" do
    should belong_to(:herbarium)
  end

  it "belongs to a tissue" do
    should belong_to(:tissue)
  end

  it "has many isolates" do
    should have_many(:isolates)
  end

  it "assigns DNA bank info after save" do
    should callback(:assign_dna_bank_info).after(:save).if :identifier_has_changed?
  end

  it "updates tissue after save" do
    should callback(:update_isolate_tissue).after(:save).if :saved_change_to_tissue_id?
  end

  xit "returns csv" do; end

  xit "assigns DNA bank info" do; end

  context "returns associated species name" do
    it "returns name of associated species if one exists" do
      species = FactoryBot.create(:species)
      individual = FactoryBot.create(:individual, species: species)

      expect(individual.species_name).to be == species.composed_name
    end

    it "returns nil if no associated species exists" do
      individual = FactoryBot.create(:individual, species: nil)
      expect(individual.species_name).to be == nil
    end
  end

  context "changes associated species name" do
    it "changes name of associated species if one exists" do
      species1 = FactoryBot.create(:species)
      species2 = FactoryBot.create(:species)

      individual = FactoryBot.create(:individual, species: species1)

      expect { individual.species_name = species2.composed_name }.to change { individual.species }.to species2
    end

    it "creates new associated species if none exists" do
      species_name = Faker::Lorem.word

      expect { subject.species_name = species_name }.to change { Species.count }.by 1
    end

    it "does not change associated species if nil is provided" do
      species = FactoryBot.create(:species)
      individual = FactoryBot.create(:individual, species: species)

      expect { individual.species_name = nil }.not_to change { individual.species }
    end

    it "removes associated species if an empty string is provided" do
      species = FactoryBot.create(:species)
      individual = FactoryBot.create(:individual, species: species)

      expect { individual.species_name = '' }.to change { individual.species }.to nil
    end
  end

  context "updates isolates tissue" do
    it "updates tissue of all associated isolates" do
      individual = FactoryBot.create(:individual)
      isolate = FactoryBot.create(:isolate, individual: individual)
      tissue = FactoryBot.create(:tissue)

      expect { individual.update(tissue: tissue) }.to change { isolate.reload.tissue }.to(tissue)
    end
  end
end