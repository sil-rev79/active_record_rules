# frozen_string_literal: true

RSpec.describe ActiveRecordRules do
  define_record "Salutation" do |t|
    t.string :greeting
    t.string :farewell
  end

  define_record "Person" do |t|
    t.string :name
    t.boolean :greetable
    t.boolean :farewellable
  end

  describe "loading rules from a file" do
    subject { TestHelper.matches }

    before do
      TestHelper.matches = []
      described_class.load_files([ "#{__dir__}/rules_initial.rules.rb" ])

      Salutation.create!(greeting: "Hi", farewell: "Bye")
      Person.create!(name: "John", greetable: true, farewellable: true)
      Person.create!(name: "Jane", greetable: true, farewellable: false)
      Person.create!(name: "Joan", greetable: false, farewellable: true)
      Person.create!(name: "Jake", greetable: false, farewellable: false)
    end

    it { is_expected.to contain_exactly("Hi, John", "Hi, Jane") }
  end
end
