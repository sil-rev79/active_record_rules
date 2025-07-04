define_rule("Free shipping") do
  after_save(<<~MATCH)
    Order(id = <order_id>)
    <ids_and_names> = array([<item_id>, <name>, <orders>]) {
      OrderItem(<order_id>, <item_id>)
      Item(id = <item_id>, <name>)
      <orders> = array([<order_id2>, <name2>]) {
        OrderItem(order_id =<order_id2>, <item_id>)
        Order(id = <order_id2>, name = <name2>)
      }
    }
    # <count> > 10
  MATCH

  on_match do
    pp "Discounting order #{order_id} by 10%"
  end
  on_unmatch do
    pp "Removing 10% discount from #{order_id}"
  end
end
