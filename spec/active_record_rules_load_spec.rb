# frozen_string_literal: true

class Salutation < TestRecord; end
class Person < TestRecord; end

RSpec.describe ActiveRecordRules do
  before do
    define_tables do |schema|
      schema.create_table :salutations do |t|
        t.string :greeting
        t.string :farewell
      end

      schema.create_table :people do |t|
        t.string :name
        t.boolean :greetable
        t.boolean :farewellable
      end
    end
  end

  describe "loading rules from a file" do
    subject { described_class.execution_context }

    before do
      described_class.load_rules("#{__dir__}/rules-initial.rrb")
      described_class.execution_context = []

      Salutation.create!(greeting: "Hi", farewell: "Bye")
      Person.create!(name: "John", greetable: true, farewellable: true)
      Person.create!(name: "Jane", greetable: true, farewellable: false)
      Person.create!(name: "Joan", greetable: false, farewellable: true)
      Person.create!(name: "Jake", greetable: false, farewellable: false)
    end

    it { is_expected.to eq(["Hi, John", "Hi, Jane"]) }

    context "when updating rules, with default settings" do
      before do
        described_class.load_rules("#{__dir__}/rules-initial.rrb")
      end

      it { is_expected.to eq(["Hi, John", "Hi, Jane"]) }
    end

    context "when updating rules, with trigger_matches: true" do
      before do
        described_class.load_rules("#{__dir__}/rules-update.rrb", trigger_matches: true)
      end

      it { is_expected.to eq(["Hi, John", "Hi, Jane", "Hi there, John", "Hi there, Jane"]) }
    end

    context "when updating rules, with trigger_unmatches: true" do
      before do
        described_class.load_rules("#{__dir__}/rules-update.rrb", trigger_unmatches: true)
      end

      it { is_expected.to eq(["Bye, John", "Bye, Joan"]) }
    end

    context "when updating rules, with trigger_matches: true and trigger_unmatches: true" do
      before do
        described_class.load_rules("#{__dir__}/rules-update.rrb", trigger_matches: true, trigger_unmatches: true)
      end

      it { is_expected.to eq(["Hi there, John", "Hi there, Jane", "Bye, John", "Bye, Joan"]) }
    end
  end
end
