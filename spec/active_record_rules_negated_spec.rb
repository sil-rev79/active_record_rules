# frozen_string_literal: true

class Racer < TestRecord; end

RSpec.describe ActiveRecordRules do
  before do
    define_tables do |schema|
      schema.create_table :racers do |t|
        t.integer :race_time
        t.integer :race_id
        t.boolean :winner
      end
    end

    described_class.define_rule <<~RULE
      after commit rule: the fastest is the winner
        Racer(<id>, <race_id>, <race_time>)
        not { Racer(<race_id>, race_time < <race_time>) }
      on match
        Racer.find(id).update!(winner: true)
      on unmatch
        Racer.find(id).update!(winner: false)
    RULE
  end

  describe "examples" do
    let!(:racer) { Racer.create!(race_time: 10) }

    it "marks a sole racer as a winner" do
      expect(racer.reload.winner).to be true
    end

    context "with a faster racer" do
      let!(:faster_racer) { Racer.create!(race_time: 5) }

      it "unmarks the original racer as a winner" do
        expect(racer.reload.winner).to be false
      end

      it "marks the faster racer as a winner" do
        expect(faster_racer.reload.winner).to be true
      end
    end

    context "with a slower racer" do
      let!(:slower_racer) { Racer.create!(race_time: 15) }

      it "leaves the original racer as a winner" do
        expect(racer.reload.winner).to be true
      end

      it "does not mark the slower racer as a winner" do
        expect(slower_racer.reload.winner).to be_nil
      end
    end

    context "with another racer of the same time" do
      let!(:same_racer) { Racer.create!(race_time: 10) }

      it "leaves the original racer as a winner" do
        expect(racer.reload.winner).to be true
      end

      it "marks the new racer as a winner" do
        expect(same_racer.reload.winner).to be true
      end
    end

    context "with one faster and one slower racer" do
      let!(:slower_racer) { Racer.create!(race_time: 15) }
      let!(:faster_racer) { Racer.create!(race_time: 5) }

      it "unmarks the original racer as a winner" do
        expect(racer.reload.winner).to be false
      end

      it "marks the faster racer as a winner" do
        expect(faster_racer.reload.winner).to be true
      end

      it "does not mark the slower racer as a winner" do
        expect(slower_racer.reload.winner).to be_nil
      end
    end

    context "with a slower racer in a separate race" do
      let!(:other_racer) { Racer.create!(race_id: 2, race_time: 15) }

      it "marks the new racer as a winner" do
        expect(other_racer.reload.winner).to be true
      end

      it "leaves the existing racer as a winner" do
        expect(racer.reload.winner).to be true
      end
    end
  end

  describe "properties" do
    context "with no duplicate times" do # rubocop:disable RSpec/EmptyExampleGroup
      generate(times: array(int(0..100), length: 1..).map(&:uniq))

      before do
        times.each { Racer.create!(race_time: _1) }
      end

      it_always "has a single winner" do
        expect(Racer.where(winner: true).size).to eq(1)
      end
    end

    context "with multiple races" do # rubocop:disable RSpec/EmptyExampleGroup
      generate(
        times: array(
          tuple(maybe(int(1..3)), int(0..100)),
          length: 1..
        )
      )

      before do
        times.each do |race_id, time|
          Racer.create!(race_id: race_id, race_time: time)
        end
      end

      it_always "marks multiple winners with the same time" do
        times.map(&:first).uniq.each do |race_id|
          expect(Racer.where(race_id: race_id, winner: true).pluck(:race_time).uniq.size).to eq(1)
        end
      end
    end
  end
end
