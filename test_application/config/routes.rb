Rails.application.routes.draw do
  resources :orders
  resources :items
  mount ActiveRecordRules::Engine => "/active_record_rules"

  direct :order_item do
      "..."
  end
end
