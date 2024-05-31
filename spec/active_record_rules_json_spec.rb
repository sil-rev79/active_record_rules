# frozen_string_literal: true

class Counter < TestRecord; end
class Countable < TestRecord; end

RSpec.describe ActiveRecordRules do
  before do
    define_tables do |schema|
      schema.create_table :counters do |t|
        case described_class.dialect
        in :sqlite
          t.json :definition
        in :postgres
          t.jsonb :definition
        end
        t.integer :count, default: 0
      end

      schema.create_table :countables do |t|
        t.integer :value
      end
    end
  end

  describe "a counter using JSON-based conditions", restrict_database: :sqlite do
    before do
      described_class.define_rule(<<~RULE)
        rule A rule
          Counter(<id>, <lower_bound> = definition.lower_bound,
                        <upper_bound> = definition["upper_bound"])
          Countable(<lower_bound> < value, value < <upper_bound>)
        on match
          Counter.find(id).increment!(:count)
        on unmatch
          Counter.find(id).decrement!(:count)
      RULE
    end

    let(:counter) { Counter.create!(definition: { lower_bound: 0, upper_bound: 10 }) }

    context "with no countable values" do
      it "has a count of zero" do
        expect(counter.reload.count).to be_zero
      end
    end

    context "with a countable value in range" do
      let!(:countable) { Countable.create!(value: 5) }

      it "has a count of one" do
        expect(counter.reload.count).to eq(1)
      end

      it "notices the countable value moving out of range" do
        countable.update!(value: 15)
        expect(counter.reload.count).to be_zero
      end

      it "notices the counter moving its range" do
        counter.update!(definition: { lower_bound: 15, upper_bound: 25 })
        expect(counter.reload.count).to be_zero
      end

      it "notices the countable value disappearing" do
        countable.destroy!
        expect(counter.reload.count).to be_zero
      end
    end
  end
end
