# frozen_string_literal: true

class User < TestRecord; end
class Order < TestRecord; end
class Item < TestRecord; end
class OrderItem < TestRecord; end

RSpec.describe ActiveRecordRules do
  subject { order.reload.discount }

  let(:matches) { TestHelper.matches }
  let(:user) { User.create! }
  let(:order) { Order.create!(user_id: user.id) }

  before do
    define_tables do |schema|
      schema.create_table :users do |t|
        t.boolean :vip_user
      end

      schema.create_table :orders do |t|
        t.references :user
        t.string :status, default: "pending"
        t.float :discount, default: 0
      end

      schema.create_table :items do |t|
        t.float :sale_discount, default: 0
      end

      schema.create_table :order_items do |t|
        t.references :order
        t.references :item
        t.integer :quantity
        t.float :value
      end
    end

    described_class.define_rule(<<~RULE)
      rule Apply a 10% discount to pending orders above $100 (ignoring sale items), for VIP users
        Order(id = <order_id>, <user_id>, status = "pending")
        User(id = <user_id>, vip_user = true)
        <order_value> = sum(<value> * <quantity>) {
          OrderItem(<order_id>, <item_id>, <quantity>, <value>)
          Item(id = <item_id>, sale_discount = 0)
        }
        <order_value> > 100
      on match
        Order.find(order_id).update!(discount: 0.1)
      on unmatch
        order = Order.find(order_id)
        # If the order has been completed, then we don't touch it any more
        order.update!(discount: 0) unless order.status == "completed"
    RULE
  end

  context "with a non-VIP user" do
    context "with an empty order" do
      it { is_expected.to be_zero }
    end

    context "with a single item worth over 100" do
      let(:item) { Item.create! }

      before { OrderItem.create!(order_id: order.id, item_id: item.id, quantity: 1, value: 101) }

      it { is_expected.to be_zero }
    end

    context "with a quantity worth over 100" do
      let(:item) { Item.create! }

      before { OrderItem.create!(order_id: order.id, item_id: item.id, quantity: 2, value: 51) }

      it { is_expected.to be_zero }
    end

    context "with two items together worth 100" do
      let(:item1) { Item.create! }
      let(:item2) { Item.create! }

      before do
        OrderItem.create!(order_id: order.id, item_id: item1.id, quantity: 1, value: 31)
        OrderItem.create!(order_id: order.id, item_id: item2.id, quantity: 1, value: 71)
      end

      it { is_expected.to be_zero }
    end

    context "with two items together worth 100, but one is on sale" do
      let(:item1) { Item.create! }
      let(:item2) { Item.create!(sale_discount: 0.1) }

      before do
        OrderItem.create!(order_id: order.id, item_id: item1.id, quantity: 1, value: 31)
        OrderItem.create!(order_id: order.id, item_id: item2.id, quantity: 1, value: 71)
      end

      it { is_expected.to be_zero }
    end
  end

  context "with a VIP user" do
    before { user.update!(vip_user: true) }

    context "with an empty order" do
      it { is_expected.to be_zero }
    end

    context "with a single item worth over 100" do
      let(:item) { Item.create! }

      before { OrderItem.create!(order_id: order.id, item_id: item.id, quantity: 1, value: 101) }

      it { is_expected.not_to be_zero }
    end

    context "with a quantity worth over 100" do
      let(:item) { Item.create! }

      before { OrderItem.create!(order_id: order.id, item_id: item.id, quantity: 2, value: 51) }

      it { is_expected.not_to be_zero }
    end

    context "with two items together worth 100" do
      let(:item1) { Item.create! }
      let(:item2) { Item.create! }

      before do
        OrderItem.create!(order_id: order.id, item_id: item1.id, quantity: 1, value: 31)
        OrderItem.create!(order_id: order.id, item_id: item2.id, quantity: 1, value: 71)
      end

      it { is_expected.not_to be_zero }

      describe "after completing" do
        before { order.update!(status: "completed") }

        it { is_expected.not_to be_zero }
      end
    end

    context "with two items together worth 100, but one is on sale" do
      let(:item1) { Item.create! }
      let(:item2) { Item.create!(sale_discount: 0.1) }

      before do
        OrderItem.create!(order_id: order.id, item_id: item1.id, quantity: 1, value: 31)
        OrderItem.create!(order_id: order.id, item_id: item2.id, quantity: 1, value: 71)
      end

      it { is_expected.to be_zero }
    end
  end
end
