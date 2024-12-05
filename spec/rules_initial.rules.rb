# frozen_string_literal: true

define_rule("greet people who are greetable") do
  later(<<~MATCH)
    Salutation(<greeting>)
    Person(<name>, greetable = true)
  MATCH
  on_match do
    TestHelper.matches.push("#{greeting}, #{name}")
  end
  on_unmatch do
    TestHelper.matches.delete("#{greeting}, #{name}")
  end
end

define_rule("Farewell People") do
  later(<<~MATCH)
    Salutation(
      <farewell>
    )
    Person(
      <name>,
      farewellable = true
    )
  MATCH
  on_unmatch do
    TestHelper.matches.push("#{farewell}, #{name}")
  end
end
