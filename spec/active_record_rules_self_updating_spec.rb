# frozen_string_literal: true

class Number < TestRecord; end

RSpec.describe ActiveRecordRules do
  subject { number.reload.value }

  let(:number) { Number.create!(value: 0) }

  before do
    define_tables do |schema|
      schema.create_table :numbers do |t|
        t.integer :value
      end
    end

    described_class.define_rule(<<~RULE)
      after commit rule: increments number to 10
        Number(<id>, <value>, value < 10)
      on match
        Number.find(id).update!(value: value + 1)
    RULE
  end

  it { is_expected.to eq(10) }
end
