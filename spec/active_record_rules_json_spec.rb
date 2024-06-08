# frozen_string_literal: true

class Counter < TestRecord; end

class Countable < TestRecord
  enum status: {
    planned: 0,
    active: 1,
    completed: 2
  }
end

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
        t.integer :status
      end
    end
  end

  describe "a counter using JSON-based conditions" do
    before do
      described_class.define_rule(<<~RULE)
        async rule: A rule
          Counter(<id>,
                  <statuses> = definition.statuses[*].text as text[],
                  <lower_bound> = definition.lower_bound as integer,
                  <upper_bound> = definition["upper_bound"] as integer)
          Countable(
            <lower_bound> < value,
            value < <upper_bound>,
            status:s in <statuses>
          )
        on match
          Counter.find(id).increment!(:count)
        on unmatch
          Counter.find(id).decrement!(:count)
      RULE
    end

    let!(:counter) do
      Counter.create!(
        definition: { lower_bound: 0,
                      upper_bound: 10,
                      statuses: [{ text: "planned" },
                                 { text: "active" }] }
      )
    end

    context "with no countable values" do
      it "has a count of zero" do
        expect(counter.reload.count).to be_zero
      end
    end

    context "with a countable value in range" do
      let!(:countable) do
        Countable.create!(value: 5, status: "planned")
      end

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
