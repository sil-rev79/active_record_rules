define_rule("10% discount over $100") do
  later(<<~MATCH)
    # Match every order in the system
    Order(id = <order_id>)

    # Gather the ids and names of each thing
    <total_value_cents> = sum(<price_cents> * <count>) {
      OrderItem(<order_id>, <item_id>, <count>)
      Item(id = <item_id>, <price_cents>)
    }

    <all_items> = array([<name>, <count>, <item_id>, <price_cents>]) {
      OrderItem(<order_id>, <item_id>, <count>)
      Item(id = <item_id>, <name>, <price_cents>)
    }

    <total_value_cents> > 100
  MATCH

  on_match do
    OrderDiscount.create!(
      key: "OVER100",
      order_id:,
      value: total_value_cents * 0.1
    )
  end
  on_update do
    OrderDiscount.find_by(
      key: "OVER100",
      order_id: order_id.new,
    ).update!(value: total_value_cents.new * 0.1)
  end
  on_unmatch do
    OrderDiscount.find_by(
      key: "OVER100",
      order_id:,
    )&.destroy!
  end
end
