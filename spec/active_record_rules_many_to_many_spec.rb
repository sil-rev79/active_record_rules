# frozen_string_literal: true

require "active_record"

RSpec.describe ActiveRecordRules do
  describe "detecting poker hands" do
    define_record "Card" do |t|
      t.string :suit
      t.integer :rank

      has_many :hand_card, dependent: :destroy
      has_many :hands, through: :hand_card
    end

    define_record "Hand" do |t|
      t.string :description

      has_many :hand_card, dependent: :destroy
      has_many :cards, through: :hand_card
    end

    define_record "HandCard" do |t|
      t.references :hand
      t.references :card

      belongs_to :card
      belongs_to :hand
    end

    before do
      ["spades", "clubs", "hearts", "diamonds"].each do |suit|
        (1..13).each do |rank|
          Card.create!(suit: suit, rank: rank)
        end
      end

      described_class.define_rule("straight flush") do
        later(<<~MATCH)
          Hand(<id>)

          HandCard(hand_id = <id>, card_id = <card1_id>)
          Card(id = <card1_id>, suit = <suit>, rank = <rank>)

          HandCard(hand_id = <id>, <card2_id> = card_id)
          Card(id = <card2_id>, suit = <suit>, rank = <rank> + 1)

          HandCard(hand_id = <id>, <card3_id> = card_id)
          Card(id = <card3_id>, suit = <suit>, rank = <rank> + 2)

          HandCard(hand_id = <id>, <card4_id> = card_id)
          Card(id = <card4_id>, suit = <suit>, rank = <rank> + 3)

          HandCard(hand_id = <id>, <card5_id> = card_id)
          Card(id = <card5_id>, suit = <suit>, rank = <rank> + 4)
        MATCH
        on_match do
          Hand.find(id).update!(description: "straight #{suit} flush from #{rank} to #{rank + 4}")
        end
        on_unmatch do
          Hand.find(id).update!(description: nil)
        end
      end
    end

    context "with a straight flush" do
      subject(:hand) { Hand.create! }

      it "is matched as a straight flush" do
        hand.update!(cards: Card.where(suit: "hearts", rank: [4, 5, 6, 7, 8]))
        expect(hand.reload.description).to eq("straight hearts flush from 4 to 8")
      end

      it "updates when adding a card" do
        hand.update!(cards: Card.where(suit: "hearts", rank: [4, 5, 6, 7]))
        # Now add 8
        hand.update!(cards: Card.where(suit: "hearts", rank: [4, 5, 6, 7, 8]))
        expect(hand.reload.description).to eq("straight hearts flush from 4 to 8")
      end

      it "does not update when removing a card" do
        hand.update!(cards: Card.where(suit: "hearts", rank: [4, 5, 6, 7, 8]))
        # Now remove 8
        hand.update!(cards: Card.where(suit: "hearts", rank: [4, 5, 6, 7]))
        expect(hand.reload.description).to eq("straight hearts flush from 4 to 8")
      end

      it "does not update when replacing a card" do
        hand.update!(cards: Card.where(suit: "hearts", rank: [4, 5, 6, 7, 8]))
        # Now replace 8 with 9
        hand.update!(cards: Card.where(suit: "hearts", rank: [4, 5, 6, 7, 9]))
        expect(hand.reload.description).to eq("straight hearts flush from 4 to 8")
      end

      context "with a monkey-patch" do
        before do
          allow_any_instance_of(ActiveRecord::Associations::CollectionAssociation).to receive(:delete) do |i, *rs| # rubocop:disable RSpec/AnyInstance
            refl = i.reflection
            refl = refl.through_reflection while refl.through_reflection?
            i.send(:delete_or_destroy, rs, refl.options[:dependent])
          end
        end

        it "updates when removing a card, with a monkey-patch" do
          hand.update!(cards: Card.where(suit: "hearts", rank: [4, 5, 6, 7, 8]))
          # Now remove 8
          hand.update!(cards: Card.where(suit: "hearts", rank: [4, 5, 6, 7]))
          expect(hand.reload.description).to be_nil
        end

        it "updates when replacing a card, with a monkey-patch" do
          hand.update!(cards: Card.where(suit: "hearts", rank: [4, 5, 6, 7, 8]))
          # Now replace 8 with 9
          hand.update!(cards: Card.where(suit: "hearts", rank: [4, 5, 6, 7, 9]))
          expect(hand.reload.description).to be_nil
        end
      end
    end
  end
end
