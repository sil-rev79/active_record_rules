# frozen_string_literal: true

RSpec.describe ActiveRecordRules do
  subject { number.reload.value }

  define_record "Number" do |t|
    t.integer :value
  end

  before do
    described_class.define_rule("increments number to 10") do
      after_commit(<<~MATCH)
        Number(<id>, <value>, value < 10)
      MATCH
      on_match do
        Number.find(id).update!(value: value + 1)
      end
    end
  end

  let(:number) { Number.create!(value: 0) }

  it { is_expected.to eq(10) }
end
