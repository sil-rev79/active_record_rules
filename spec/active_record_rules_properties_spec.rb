# frozen_string_literal: true

# For the first example group
class SupportRequest < ActiveRecord::Base; include ActiveRecordRules::Fact; end
class ClientRepresentative < ActiveRecord::Base; include ActiveRecordRules::Fact; end

# For the second example group
class Card < ActiveRecord::Base; include ActiveRecordRules::Fact; end

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

      ActiveRecordRules::Rule.define_rule(<<~RULE)
        rule notify client representative for high importance requests
          SupportRequest(client, level = "high")
          ClientRepresentative(client, name)
        on match
          TestHelper.matches << [:notify, name]
      RULE

      TestHelper.matches = []

      clients.each do |client, data|
        data[:representatives].each { ClientRepresentative.create!(client: client, name: _1) }
        data[:support_requests].each { SupportRequest.create!(client: client, level: _1) }
      end
    end

    it_always "notifies all the right people" do
      expected_matches = []
      clients.each do |_client, data|
        data[:support_requests].select { _1 == "high" }.each do
          data[:representatives].each do |rep|
            expected_matches << [:notify, rep]
          end
        end
      end
      expect(TestHelper.matches.sort).to eq(expected_matches.sort)
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

      ActiveRecordRules::Rule.define_rule(<<~RULE)
        rule three of the same suit
          Card(suit, rank = rank1)
          Card(suit, rank = rank2, rank > rank1)
          Card(suit, rank = rank3, rank > rank2)
        on match
          TestHelper.matches << [suit, [rank1, rank2, rank3]]
        on unmatch
          # What an annoying construction to delete a single element
          # of an array that possibly contains duplicates!
          TestHelper.matches.delete_at(TestHelper.matches.index([suit, [rank1, rank2, rank3]]))
      RULE

      TestHelper.matches = []
    end

    describe "always" do # rubocop:disable RSpec/EmptyExampleGroup
      generate(
        cards: array(
          tuple(
            one_of("heart", "diamond", "club", "spade"),
            one_of("2", "3", "4", "5", "6", "7", "8", "9", "10", "jack", "queen", "king", "ace"),
            boolean, # whether to retract this fact
            boolean, # whether to re-assert this fact after it's retracted
            maybe(one_of("heart", "diamond", "club", "spade")) # a new suit to update to
          )
        )
      )
      let!(:card_records) do
        cards.map do |suit, rank|
          Card.create!(suit: suit, rank: rank)
        end
      end

      it_always "matches on groups of three" do
        expected_matches = cards.group_by(&:first).flat_map do |suit, cards|
          ranks = cards.map(&:second)
          ranks.product(ranks, ranks).map do |rank1, rank2, rank3|
            next unless rank1 < rank2 && rank2 < rank3

            [suit, [rank1, rank2, rank3]]
          end
        end.compact
        expect(TestHelper.matches.sort).to eq(expected_matches.sort)
      end

      it_always "matches on groups of three after deleting some records" do
        cards.zip(card_records).each do |card, record|
          record.destroy! if card[2]
        end

        expected_matches = cards.group_by(&:first).flat_map do |suit, cards|
          ranks = cards.reject { _3 }.map(&:second)
          ranks.product(ranks, ranks).map do |rank1, rank2, rank3|
            next unless rank1 < rank2 && rank2 < rank3

            [suit, [rank1, rank2, rank3]]
          end
        end.compact
        expect(TestHelper.matches.sort).to eq(expected_matches.sort)
      end

      it_always "matches on groups of three after deleting and restoring some records" do
        cards.zip(card_records).each do |card, record|
          record.destroy! if card[2]
        end

        cards.each do |suit, rank, destroy, restore|
          Card.create!(suit: suit, rank: rank) if destroy && restore
        end

        expected_matches = cards.group_by(&:first).flat_map do |suit, cards|
          ranks = cards.reject { _3 && !_4 }.map(&:second)
          ranks.product(ranks, ranks).map do |rank1, rank2, rank3|
            next unless rank1 < rank2 && rank2 < rank3

            [suit, [rank1, rank2, rank3]]
          end
        end.compact
        expect(TestHelper.matches.sort).to eq(expected_matches.sort)
      end

      it_always "matches on groups of three after updating some records" do
        cards.zip(card_records).each do |card, record|
          record.update!(suit: card[4]) if card[4]
        end

        expected_matches = cards.group_by { _5 || _1 }.flat_map do |suit, cards|
          ranks = cards.map(&:second)
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

      describe "four suits, with duplicates, and a no-op update" do
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
    end
  end
end
