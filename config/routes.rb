ActiveRecordRules::Engine.routes.draw do
  get "/", to: "rules#index", as: "index"
  get "/:id", to: "rules#show", as: "rule"
  post "/:id", to: "rules#trigger", as: "trigger"
  get "/:rule_id/:match_id", to: "rules#show_match", as: "rule_rule_match"
end
