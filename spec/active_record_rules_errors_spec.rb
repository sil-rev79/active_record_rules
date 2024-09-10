# frozen_string_literal: true

class Fraction < TestRecord; end

RSpec.describe ActiveRecordRules do
  before do
    define_tables do |schema|
      schema.create_table :fractions do |t|
        t.integer :numerator
        t.integer :denominator
        t.integer :int_value
      end
    end

    described_class.define_rule <<~RULE
      async rule: calculate fraction value
        Fraction(<id>, <numerator>, <denominator>)
      on match
        Fraction.find(id).update!(int_value: numerator / denominator)
    RULE
  end

  context "with 1/2" do
    let(:fraction) { Fraction.create!(numerator: 1, denominator: 2) }

    it "calculates the integer value" do
      expect(fraction.reload.int_value).to eq(0)
    end
  end

  context "with 1/0" do
    let(:fraction) { Fraction.create!(numerator: 1, denominator: 0) }

    it "stores an error" do # rubocop:disable RSpec/MultipleExpectations
      expect { fraction }.to raise_error(/1 of 1 failed/)
      expect(ActiveRecordRules::RuleMatch.pluck(:failed_since).compact).not_to be_empty
    end
  end
end
