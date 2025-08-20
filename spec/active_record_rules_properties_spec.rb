# frozen_string_literal: true

RSpec.describe ActiveRecordRules do
  # the basic idea of this test is taken from the Clara Rules documentation
  describe "SupportRequest example" do # rubocop:disable RSpec/EmptyExampleGroup
    generate(
      clients: hashmap(
        string(length: 5..),
        hashmap(
          representatives: array(string(length: 5..)).map(&:uniq),
          support_requests: array(one_of("low", "medium", "high"))
        )
      )
    )

    define_record "SupportRequest" do |t|
      t.string :client
      t.string :level
    end

    define_record "ClientRepresentative" do |t|
      t.string :name
      t.string :client
    end

    before do
      described_class.define_rule("notify client representative for high importance requests") do
        later(<<~MATCH)
          SupportRequest(<client>, level = "high")
          ClientRepresentative(<client>, <name>)
        MATCH
        on_match do
          TestHelper.matches << [ :notify, name ]
        end
      end

      TestHelper.matches = []
      described_class.logger = nil # to speed these tests up, we turn off the logging entirely

      clients.each do |client, data|
        data[:representatives].each { ClientRepresentative.create!(client: client, name: _1) }
        data[:support_requests].each { SupportRequest.create!(client: client, level: _1) }
      end
    end

    it_always "notifies all the right people" do
      expected_matches = []
      clients.each_value do |data|
        data[:support_requests].select { _1 == "high" }.each do
          data[:representatives].each do |rep|
            expected_matches << [ :notify, rep ]
          end
        end
      end
      expect(TestHelper.matches.sort).to eq(expected_matches.sort)
    end
  end

  describe "rule definition" do # rubocop:disable RSpec/EmptyExampleGroup
    generate(
      steps: array(
        one_of(
          tuple(
            one_of("heart", "diamond", "club", "spade"),
            one_of("2", "3", "4", "5", "6", "7", "8", "9", "10", "jack", "queen", "king", "ace")
          ),
          # A sole rank is a rule which counts cards of that rank
          one_of("2", "3", "4", "5", "6", "7", "8", "9", "10", "jack", "queen", "king", "ace")
        )
      ).map(&:uniq)
    )

    let!(:counts) { Hash.new { _1[_2] = 0 } }

    define_record "Card" do |t|
      t.string :suit
      t.string :rank
    end

    before do
      counts.extend(ActiveRecordRules::Definer)

      steps.each do |step|
        case step
        in [suit, rank]
          Card.create!(suit: suit, rank: rank)
        in rank
          counts.define_rule("counting #{rank}s") do
            later(<<~MATCH)
              Card(rank = "#{rank}", <rank>)
            MATCH
            on_match do
              self[rank] += 1
            end
          end
        end
      end
    end

    it_always "matches objects which are created later" do
      expect(counts)
        .to eq(
          steps.each_with_index.map do |step, i|
            next unless step.is_a?(String)

            # Only look at the steps which come *later*
            count = steps[i..]
               .reject { _1.is_a?(String) }
               .map(&:second)
               .select { _1 == step }
               .size
            next if count.zero?

            [ step, count ]
          end.compact.to_h
        )
    end
  end

  describe "Card example" do
    define_record "Card" do |t|
      t.string :suit
      t.string :rank
    end

    before do
      described_class.define_rule("three of the same suit") do
        later(<<~MATCH)
          Card(<suit>, rank = <rank1>)
          Card(<suit>, rank = <rank2>, rank > <rank1>)
          Card(<suit>, rank = <rank3>, rank > <rank2>)
        MATCH
        on_match do
          TestHelper.matches << [ suit, [ rank1, rank2, rank3 ] ]
        end
        on_unmatch do
          # What an annoying construction to delete a single element
          # of an array that possibly contains duplicates!
          TestHelper.matches.delete_at(TestHelper.matches.index([ suit, [ rank1, rank2, rank3 ] ]))
        end
      end

      TestHelper.matches = []
      described_class.logger = nil # to speed these tests up, we turn off the logging entirely
    end

    describe "always" do # rubocop:disable RSpec/EmptyExampleGroup
      generate(
        cards: array(
          tuple(
            one_of("heart", "diamond", "club", "spade"),
            one_of("2", "3", "4", "5", "6", "7", "8", "9", "10", "jack", "queen", "king", "ace"),
            # A collection of potential types of updates
            array(
              one_of(
                # Update the suit
                tuple(:suit, one_of("heart", "diamond", "club", "spade")),
                # Update the rank
                tuple(:rank, one_of("2", "3", "4", "5", "6", "7", "8", "9", "10", "jack", "queen", "king", "ace")),
                # Delete the object
                :delete,
                # Create a new object with the same values
                :clone
              ),
              length: 0..4
            )
          )
        )
      )

      let!(:card_state) do
        card_state = []
        records = cards.map do |suit, rank|
          card_state << { suit: suit, rank: rank }
          Card.create!(suit: suit, rank: rank)
        end

        (0..).each do |update_number|
          any_updates = false
          records.zip(cards.map(&:third), 0..).each do |record, updates, index|
            update = updates[update_number]
            next unless update

            any_updates = true
            case update
            in [:suit, suit]
              next if record.destroyed?

              record.update!(suit: suit)
              card_state[index][:suit] = suit
            in [:rank, rank]
              next if record.destroyed?

              record.update!(rank: rank)
              card_state[index][:rank] = rank
            in :delete
              record.destroy!
              card_state[index] = nil
            in :clone
              record.dup.save!
              card_state << { suit: record.suit, rank: record.rank }
            end
          end
          break unless any_updates
        end

        card_state.compact
      end

      it_always "matches on groups of three" do
        expected_matches = card_state.group_by { _1[:suit] }.flat_map do |suit, cards|
          ranks = cards.pluck(:rank)
          ranks.product(ranks, ranks).map do |rank1, rank2, rank3|
            next unless rank1 < rank2 && rank2 < rank3

            [ suit, [ rank1, rank2, rank3 ] ]
          end
        end.compact
        expect(TestHelper.matches.sort).to eq(expected_matches.sort)
      end
    end

    describe "found by failing property tests:" do
      describe "multiple suit updates" do
        before do
          card1 = Card.create!(suit: "heart", rank: "2")
          card2 = Card.create!(suit: "heart", rank: "3")
          Card.create!(suit: "diamond", rank: "4")
          card1.update!(suit: "diamond")
          card2.update!(suit: "diamond")
        end

        it "picks up on multiple card updates" do
          expect(TestHelper.matches.sort).to eq([ [ "diamond", [ "2", "3", "4" ] ] ])
        end
      end

      describe "multiple suit updates, but in a different order" do
        before do
          card1 = Card.create!(suit: "heart", rank: "2")
          Card.create!(suit: "diamond", rank: "3")
          card2 = Card.create!(suit: "heart", rank: "4")
          card1.update!(suit: "diamond")
          card2.update!(suit: "diamond")
        end

        it "picks up on multiple card updates" do
          expect(TestHelper.matches.sort).to eq([ [ "diamond", [ "2", "3", "4" ] ] ])
        end
      end

      describe "multiple suit updates, taking one match to a different match" do
        before do
          card1 = Card.create!(suit: "heart", rank: "2")
          card2 = Card.create!(suit: "heart", rank: "3")
          card3 = Card.create!(suit: "heart", rank: "4")
          card1.update!(suit: "diamond")
          card2.update!(suit: "diamond")
          card3.update!(suit: "diamond")
        end

        it "picks up on multiple card updates" do
          expect(TestHelper.matches.sort).to eq([ [ "diamond", [ "2", "3", "4" ] ] ])
        end
      end

      describe "four cards, with duplicates, and a no-op update" do
        before do
          Card.create!(suit: "heart", rank: "2")
          Card.create!(suit: "heart", rank: "2")
          Card.create!(suit: "heart", rank: "4")
          card = Card.create!(suit: "heart", rank: "3")
          card.update!(suit: "heart")
        end

        it "picks up on multiple card updates" do
          expect(TestHelper.matches.sort).to eq([ [ "heart", [ "2", "3", "4" ] ], [ "heart", [ "2", "3", "4" ] ] ])
        end
      end

      describe "four diamonds, with three updated to match in hearts" do
        before do
          card1 = Card.create!(suit: "diamond", rank: "2")
          card2 = Card.create!(suit: "diamond", rank: "3")
          Card.create!(suit: "diamond", rank: "3")
          card3 = Card.create!(suit: "diamond", rank: "4")
          card1.update!(suit: "heart")
          card2.update!(suit: "heart")
          card3.update!(suit: "heart")
        end

        it "picks up on multiple card updates" do
          expect(TestHelper.matches.sort).to eq([ [ "heart", [ "2", "3", "4" ] ] ])
        end
      end

      describe "four cards, one created with dup" do
        before do
          Card.create!(suit: "heart", rank: "2")
          Card.create!(suit: "heart", rank: "3")
          card = Card.create!(suit: "heart", rank: "4")
          card.dup.save!
        end

        it "matches the resulting match" do
          expect(TestHelper.matches.sort).to eq([ [ "heart", [ "2", "3", "4" ] ], [ "heart", [ "2", "3", "4" ] ] ])
        end
      end
    end
  end

  describe "tracking operations" do # rubocop:disable RSpec/EmptyExampleGroup
    generate(
      timing: one_of("after_save", "after_commit", "after_request", "later"),
      operations: recursive do |gen|
        array(
          one_of(
            tuple(:update, int(0..10), int(0..10)),
            tuple(:transaction, gen),
            tuple(:request, gen)
          )
        )
      end.map { [ [ :transaction, _1 ] ] }
    )

    def run_operations(operations)
      operations.each do |operation|
        case operation
        in [:update, id, value]
          Record.find_or_initialize_by(id: id).update!(value: value)
        in [:transaction, sub_operations]
          ActiveRecord::Base.transaction do
            run_operations(sub_operations)
          end
        in [:request, sub_operations]
          ActiveRecordRules.wrap_request do
            run_operations(sub_operations)
          end
        end
      end
    end

    define_record "Record" do |t|
      t.integer :value
    end

    before do
      t = timing # bind a local variable, so we can access it in the definition block
      described_class.define_rule("Keep track of updates") do
        send(t, <<~MATCH)
          Record(<id>, <value>)
        MATCH
        on_match do
          TestHelper.matches[id] = value
        end
      end

      TestHelper.matches = {}
      described_class.logger = nil # to speed these tests up, we turn off the logging entirely
    end

    it_always "matches the underlying data", num_tests: 1000 do
      run_operations(operations)
      expect(TestHelper.matches).to eq(Record.all.pluck(:id, :value).to_h)
    end

    context 'with a known example' do
      let(:timing) { 'after_commit' }

      it 'works properly with two nested transactions' do
        run_operations(
          [ [ :update, 0, 0 ],
           [ :transaction, [ [ :update, 0, 0 ], [ :update, 0, 1 ] ] ] ]
        )
        expect(TestHelper.matches).to eq(Record.all.pluck(:id, :value).to_h)
      end
    end
  end
end
