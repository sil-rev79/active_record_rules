# frozen_string_literal: true

# For the first example group
class SupportRequest < TestRecord; end
class ClientRepresentative < TestRecord; end

# For the second example group
class Card < TestRecord; end

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

    before do
      define_tables do |schema|
        schema.create_table :support_requests do |t|
          t.string :client
          t.string :level
        end

        schema.create_table :client_representatives do |t|
          t.string :name
          t.string :client
        end
      end

      described_class.define_rule(<<~RULE)
        rule notify client representative for high importance requests
          SupportRequest(<client>, level = "high")
          ClientRepresentative(<client>, <name>)
        on match
          TestHelper.matches << [:notify, name]
      RULE

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
            expected_matches << [:notify, rep]
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

    before do
      define_tables do |schema|
        schema.create_table :cards do |t|
          t.string :suit
          t.string :rank
        end
      end

      described_class.execution_context = counts

      steps.each do |step|
        case step
        in [suit, rank]
          Card.create!(suit: suit, rank: rank)
        in rank
          described_class.define_rule(<<~RULE)
            rule counting #{rank}s
              Card(rank = "#{rank}", <rank>)
            on match
              self[rank] += 1
          RULE
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

            [step, count]
          end.compact.to_h
        )
    end
  end

  describe "Card example" do
    before do
      define_tables do |schema|
        schema.create_table :cards do |t|
          t.string :suit
          t.string :rank
        end
      end

      described_class.define_rule(<<~RULE)
        rule three of the same suit
          Card(<suit>, rank = <rank1>)
          Card(<suit>, rank = <rank2>, rank > <rank1>)
          Card(<suit>, rank = <rank3>, rank > <rank2>)
        on match
          TestHelper.matches << [suit, [rank1, rank2, rank3]]
        on unmatch
          # What an annoying construction to delete a single element
          # of an array that possibly contains duplicates!
          TestHelper.matches.delete_at(TestHelper.matches.index([suit, [rank1, rank2, rank3]]))
      RULE

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

            [suit, [rank1, rank2, rank3]]
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
          expect(TestHelper.matches.sort).to eq([["diamond", ["2", "3", "4"]]])
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
          expect(TestHelper.matches.sort).to eq([["diamond", ["2", "3", "4"]]])
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
          expect(TestHelper.matches.sort).to eq([["diamond", ["2", "3", "4"]]])
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
          expect(TestHelper.matches.sort).to eq([["heart", ["2", "3", "4"]], ["heart", ["2", "3", "4"]]])
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
          expect(TestHelper.matches.sort).to eq([["heart", ["2", "3", "4"]]])
        end
      end

      # describe "four cards, one created with dup" do
      #   before do
      #     Card.create!(suit: "heart", rank: "2")
      #     Card.create!(suit: "heart", rank: "3")
      #     card = Card.create!(suit: "heart", rank: "4")
      #     card.dup.save!
      #   end

      #   it "matches the resulting match" do
      #     expect(TestHelper.matches.sort).to eq([["heart", ["2", "3", "4"]], ["heart", ["2", "3", "4"]]])
      #   end
      # end
    end
  end
end
