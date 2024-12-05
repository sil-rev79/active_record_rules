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

    described_class.define_rule("increments number to 10") do
      after_commit(<<~MATCH)
        Number(<id>, <value>, value < 10)
      MATCH
      on_match do
        Number.find(id).update!(value: value + 1)
      end
    end
  end

  it { is_expected.to eq(10) }
end
