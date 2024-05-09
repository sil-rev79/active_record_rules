# frozen_string_literal: true

class Salutation < TestRecord; end
class Person < TestRecord; end

module TestRecordModule
  class Salutation < TestRecord; end
  class Person < TestRecord; end
end

RSpec.describe ActiveRecordRules do
  before do
    define_tables do |schema|
      schema.create_table :salutations do |t|
        t.string :greeting
        t.string :farewell
      end

      schema.create_table :people do |t|
        t.string :name
        t.boolean :greetable
        t.boolean :farewellable
      end
    end
  end

  describe "rules with no constraints" do
    before do
      described_class.define_rule(<<~RULE)
        rule greet
          Salutation(<greeting>)
          Person(<name>)
        on match
          TestHelper.matches += [[greeting, name]]
        on unmatch
          TestHelper.matches -= [[greeting, name]]
      RULE

      TestHelper.matches = []
    end

    let!(:salutation) { Salutation.create!(greeting: "hello") }

    context "with John as a person" do
      let!(:john) { Person.create!(name: "John") }

      it "matches for hello/John" do
        expect(TestHelper.matches).to include(["hello", "John"])
      end

      it "unmatches when John is deleted" do
        john.destroy!
        expect(TestHelper.matches).not_to include(["hello", "John"])
      end

      it "unmatches when John changes name" do
        john.update!(name: "Johns")
        expect(TestHelper.matches).not_to include(["hello", "John"])
      end

      it "matches for the new value when John changes name" do
        john.update!(name: "Johns")
        expect(TestHelper.matches).to include(["hello", "Johns"])
      end

      it "does nothing when an unrelated attributes changes" do
        salutation.update!(farewell: "goodbye")
        expect(TestHelper.matches).to include(["hello", "John"])
      end
    end

    context "with John and Jane as people" do
      before { Person.create!(name: "John") }

      let!(:jane) { Person.create!(name: "Jane") }

      it "matches for hello/Jane" do
        expect(TestHelper.matches).to include(["hello", "Jane"])
      end

      it "unmatches Jane when Jane is deleted" do
        jane.destroy!
        expect(TestHelper.matches).not_to include(["hello", "Jane"])
      end

      it "leave John matched when Jane is deleted" do
        jane.destroy!
        expect(TestHelper.matches).to include(["hello", "John"])
      end
    end
  end

  describe "rules with a class in a module" do
    before do
      described_class.define_rule(<<~RULE)
        rule greet
          TestRecordModule::Salutation(<greeting>)
          TestRecordModule::Person(<name>)
        on match
          TestHelper.matches += [[greeting, name]]
        on unmatch
          TestHelper.matches -= [[greeting, name]]
      RULE

      TestHelper.matches = []
    end

    let!(:salutation) { TestRecordModule::Salutation.create!(greeting: "hello") }

    context "with John as a person" do
      let!(:john) { TestRecordModule::Person.create!(name: "John") }

      it "matches for hello/John" do
        expect(TestHelper.matches).to include(["hello", "John"])
      end

      it "unmatches when John is deleted" do
        john.destroy!
        expect(TestHelper.matches).not_to include(["hello", "John"])
      end

      it "unmatches when John changes name" do
        john.update!(name: "Johns")
        expect(TestHelper.matches).not_to include(["hello", "John"])
      end

      it "matches for the new value when John changes name" do
        john.update!(name: "Johns")
        expect(TestHelper.matches).to include(["hello", "Johns"])
      end

      it "does nothing when an unrelated attributes changes" do
        salutation.update!(farewell: "goodbye")
        expect(TestHelper.matches).to include(["hello", "John"])
      end
    end

    context "with John and Jane as people" do
      before { TestRecordModule::Person.create!(name: "John") }

      let!(:jane) { TestRecordModule::Person.create!(name: "Jane") }

      it "matches for hello/Jane" do
        expect(TestHelper.matches).to include(["hello", "Jane"])
      end

      it "unmatches Jane when Jane is deleted" do
        jane.destroy!
        expect(TestHelper.matches).not_to include(["hello", "Jane"])
      end

      it "leave John matched when Jane is deleted" do
        jane.destroy!
        expect(TestHelper.matches).to include(["hello", "John"])
      end
    end
  end

  describe "rules with constant constraints" do
    before do
      described_class.define_rule(<<~RULE)
        rule greet
          Salutation(<greeting>)
          Person(<name>, greetable = true)
        on match
          TestHelper.matches += [[greeting, name]]
        on unmatch
          TestHelper.matches -= [[greeting, name]]
      RULE

      described_class.define_rule(<<~RULE)
        rule farewell
          Salutation(<greeting>, <farewell>)
          Person(<name>, greetable = true)
          Person(<name>, farewellable = true)
        on match
          TestHelper.matches += [[greeting, name]]
          TestHelper.matches += [[farewell, name]]
        on unmatch
          TestHelper.matches -= [[greeting, name]]
          TestHelper.matches -= [[farewell, name]]
      RULE

      TestHelper.matches = []
    end

    context "with ten people" do
      before do
        Salutation.create!(greeting: "What's up?")
        10.times do |i|
          Person.create!(name: "Person #{i}")
        end
        Person.create!(name: "John", greetable: true)
      end

      it "only reprocesses a single Person when one is added" do
        capturing_logs do |output|
          Person.create!(name: "Jane", greetable: true)
          expect(output.string.scan(/"people_[0-9]+":([0-9]+)/).uniq).to contain_exactly(["12"])
        end
      end

      it "doesn't process any people when a Salutation is added" do
        capturing_logs do |output|
          Salutation.create!(greeting: "Yo")
          expect(output.string).not_to include("Person(")
        end
      end
    end
  end

  describe "rules with constraints between three conditions" do
    before do
      described_class.define_rule(<<~RULE)
        rule greet
          Salutation(<greeting>)
          Person(name = <name1>)
          Person(name = <name2>, name > <name1>)
        on match
          TestHelper.matches += [[greeting, name1, name2]]
        on unmatch
          TestHelper.matches -= [[greeting, name1, name2]]
      RULE

      TestHelper.matches = []
    end

    describe "adding two people, then a salutation" do
      let!(:john) { Person.create!(name: "John") }

      before do
        Person.create!(name: "Jane")
        Salutation.create!(greeting: "hello")
      end

      it "does not match twice" do
        expect(TestHelper.matches).to contain_exactly(["hello", "Jane", "John"])
      end

      it "unmatches properly" do
        john.destroy!
        expect(TestHelper.matches).to be_empty
      end
    end
  end

  describe "rules which only match a subset of records" do
    before do
      described_class.define_rule(<<~RULE)
        rule greet
          Salutation(<greeting>)
          Person(name = <name1>, greetable = true)
          Person(name = <name2>, name > <name1>)
        on match
          TestHelper.matches += [[greeting, name1, name2]]
        on unmatch
          TestHelper.matches -= [[greeting, name1, name2]]
      RULE

      TestHelper.matches = []
    end

    context "with ten people and a salutation" do
      before do
        10.times { Person.create!(name: "Person #{_1}") }
        Salutation.create!(greeting: "hi")
      end

      it "does not re-process every existing person when adding a new person" do
        # This test is checking that we do some initial filtering in
        # the database query before we do anything in Ruby. We use the
        # logs as a proxy for Ruby-side evaluation.
        capturing_logs(:info) do |output|
          Person.create!(name: "Person 5.5", greetable: true)
          expect(output.string.scan(/Rule\(([0-9]+)\)/).size).to be < 10
        end
      end
    end
  end

  describe "rules referencing non-ActiveRecord::Base classes" do
    it "fails if the class is not an ActiveRecord::Base" do
      expect { described_class.define_rule(<<~RULE) }.to raise_error(/subclasses of ActiveRecord::Base/)
        rule fail at defining
          Object()
      RULE
    end
  end

  describe "multiple rules at the same time" do
    before do
      described_class.define_rule(<<~RULE)
        rule greet
          Salutation(<greeting>, greeting != nil)
          Person(<name>)
        on match
          TestHelper.matches += [[greeting, name]]
        on unmatch
          TestHelper.matches -= [[greeting, name]]
      RULE

      described_class.define_rule(<<~RULE)
        rule farewell
          Salutation(<farewell>, farewell != nil)
          Person(<name>)
        on match
          TestHelper.matches += [[farewell, name]]
        on unmatch
          TestHelper.matches -= [[farewell, name]]
      RULE

      TestHelper.matches = []
    end

    describe "greeting John" do
      before { Salutation.create!(greeting: "hi") }

      let!(:person) { Person.create!(name: "John") }

      it "matches" do
        expect(TestHelper.matches).to eq([["hi", "John"]])
      end

      it "updates when John is renamed" do
        person.update!(name: "Jane")
        expect(TestHelper.matches).to eq([["hi", "Jane"]])
      end

      it "unmatches when John goes away" do
        person.destroy!
        expect(TestHelper.matches).to be_empty
      end
    end

    describe "farewelling John" do
      before { Salutation.create!(farewell: "bye") }

      let!(:person) { Person.create!(name: "John") }

      it "matches" do
        expect(TestHelper.matches).to eq([["bye", "John"]])
      end

      it "updates when John is renamed" do
        person.update!(name: "Jane")
        expect(TestHelper.matches).to eq([["bye", "Jane"]])
      end

      it "unmatches when John goes away" do
        person.destroy!
        expect(TestHelper.matches).to be_empty
      end
    end

    describe "greeting and farewelling John" do
      let!(:salutation) { Salutation.create!(greeting: "hi", farewell: "bye") }
      let!(:person) { Person.create!(name: "John") }

      it "matches" do
        expect(TestHelper.matches.sort).to eq([["bye", "John"], ["hi", "John"]])
      end

      it "updates when John is renamed" do
        person.update!(name: "Jane")
        expect(TestHelper.matches.sort).to eq([["bye", "Jane"], ["hi", "Jane"]])
      end

      it "updates when greeting changes" do
        salutation.update!(greeting: "hello")
        expect(TestHelper.matches.sort).to eq([["bye", "John"], ["hello", "John"]])
      end

      it "updates when farwell changes" do
        salutation.update!(farewell: "so long")
        expect(TestHelper.matches.sort).to eq([["hi", "John"], ["so long", "John"]])
      end

      it "unmatches when John goes away" do
        person.destroy!
        expect(TestHelper.matches).to be_empty
      end

      it "unmatches when greeting goes away" do
        salutation.update!(greeting: nil)
        expect(TestHelper.matches).to eq([["bye", "John"]])
      end

      it "unmatches when farwell goes away" do
        salutation.update!(farewell: nil)
        expect(TestHelper.matches).to eq([["hi", "John"]])
      end
    end
  end

  describe "rules with updates" do
    before do
      described_class.define_rule(<<~RULE)
        rule greet
          Salutation(<greeting>)
          Person(<name>)
        on match
          TestHelper.matches += [[greeting, name, 0]]
        on update
          record = TestHelper.matches.find { _1 == greeting.old && _2 == name.old }
          record[0] = greeting.new
          record[1] = name.new
          record[2] += 1
        on unmatch
          TestHelper.matches.delete_at(TestHelper.matches.index { _1 == greeting && _2 == name })
      RULE

      TestHelper.matches = []

      Salutation.create!(greeting: "hello")
    end

    context "with John as a person" do
      let!(:john) { Person.create!(name: "John") }

      it "changes value when John changes name" do
        john.update!(name: "Jane")
        expect(TestHelper.matches).to include(["hello", "Jane", 1])
      end
    end
  end

  describe "custom execution objects" do
    before do
      described_class.define_rule(<<~RULE)
        rule run custom methods
          Person(<name>)
        on match
          insert(0, name)
      RULE

      TestHelper.matches = []
    end

    context "with constant TestHelper.match value" do
      before { described_class.execution_context = TestHelper.matches }
      after { described_class.execution_context = nil }

      it "calls the methods on right object" do
        Person.create!(name: "John")
        expect(TestHelper.matches).to include("John")
      end
    end

    context "with proc returning the TestHelper.match value" do
      before { described_class.execution_context = -> { TestHelper.matches } }
      after { described_class.execution_context = nil }

      it "calls the methods on right object" do
        Person.create!(name: "John")
        expect(TestHelper.matches).to include("John")
      end
    end
  end

  describe "rule definition" do
    before do
      person # force person to be created before the rule is defined

      described_class.define_rule(<<~RULE)
        rule run custom methods
          Person(<name>)
        on match
          TestHelper.matches << name
      RULE

      TestHelper.matches = []
    end

    let!(:person) { Person.create!(name: "John") }

    it "doesn't match existing objects" do
      expect(TestHelper.matches).to be_empty
    end

    it "doesn't match existing objects after an unrelated update", skip: "Undecided semantics" do
      person.update!(greetable: true)
      expect(TestHelper.matches).to be_empty
    end

    it "does match existing objects after a relevant update" do
      person.update!(name: "Johns")
      expect(TestHelper.matches).to include("Johns")
    end

    it "matches new objects" do
      Person.create!(name: "Jane")
      expect(TestHelper.matches).to include("Jane")
    end
  end

  describe "rule deletion" do
    before do
      described_class.define_rule(<<~RULE)
        rule run custom methods
          Person(<name>)
        on unmatch # note: on UNmatch
          TestHelper.matches << name
      RULE
      TestHelper.matches = []
      Person.create!(name: "John")
    end

    it "doesn't unmatch existing objects" do
      described_class.delete_rule("run custom methods")
      expect(TestHelper.matches).to be_empty
    end
  end

  describe "modifications with lots of people" do
    before do
      described_class.define_rule(<<~RULE)
        rule run custom methods
          Salutation(<greeting>)
          Person(<name>)
        on match
          TestHelper.matches.add([greeting, name])
        on unmatch
          TestHelper.matches.delete([greeting, name])
      RULE
      TestHelper.matches = Set.new

      Salutation.create!(greeting: "hi")
      Person.insert_all((0..10_000).map { { name: "Person #{_1}" } })
      Benchmark.measure { described_class.trigger_all } # trigger everything in a batch
    end

    it "are quick to add one more person" do
      result = Benchmark.measure { Person.create!(name: "John") }
      expect(result.total).to be < 0.05
    end

    it "are quick to remove one person" do
      person = Person.all.sample
      result = Benchmark.measure { person.destroy! }
      expect(result.total).to be < 0.05
    end
  end

  describe "top-level expression constraints" do
    before do
      described_class.define_rule(<<~RULE)
        rule find salutations with "hello" as their greeting
          Salutation(<id>, <greeting>)
          "hello" = <greeting>
        on match
          TestHelper.matches.add(id)
        on unmatch
          TestHelper.matches.delete(id)
      RULE
      TestHelper.matches = Set.new
    end

    context "with a salutation of \"hello\"" do
      let!(:salutation) { Salutation.create!(greeting: "hello") }

      it "marks the salutation" do
        expect(TestHelper.matches).to include(salutation.id)
      end

      it "unmarks the salutation after changing the salutation" do
        salutation.update!(greeting: "salut")
        expect(TestHelper.matches).not_to include(salutation.id)
      end
    end

    context "with a salutation of \"hi\"" do
      let!(:salutation) { Salutation.create!(greeting: "hi") }

      it "does not mark the salutation" do
        expect(TestHelper.matches).not_to include(salutation.id)
      end
    end
  end
end
