require 'faker'

FactoryBot.define do
  factory :species do |s|
    s.author { Faker::Name.name_with_middle }
    s.author_infra { Faker::Name.name_with_middle }
    s.comment { Faker::Lorem.paragraph }
    s.composed_name { Faker::Lorem.word }
    s.genus_name { Faker::Lorem.word }
    s.german_name { Faker::Lorem.word }
    s.infraspecific { Faker::Lorem.word }
    s.species_component { Faker::Lorem.word }
    s.species_epithet { Faker::Lorem.word }
    s.synonym { Faker::Lorem.word }
  end
end