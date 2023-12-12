# frozen_string_literal: true

class Salutation < ActiveRecord::Base; include ActiveRecordRules::Fact; end
class Person < ActiveRecord::Base; include ActiveRecordRules::Fact; end

class NonFact < ActiveRecord::Base; end

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
      ActiveRecordRules::Rule.define_rule(<<~RULE)
        rule greet
          Salutation(greeting)
          Person(name)
        on match
          # puts "match \#{greeting}/\#{name}"
          TestHelper.matches += [[greeting, name]]
        on unmatch
          # puts "unmatch \#{greeting}/\#{name}"
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

  describe "rules with constant constraints" do
    before do
      ActiveRecordRules::Rule.define_rule(<<~RULE)
        rule greet
          Salutation(greeting)
          Person(name, greetable = true)
        on match
          TestHelper.matches += [[greeting, name]]
        on unmatch
          TestHelper.matches -= [[greeting, name]]
      RULE

      ActiveRecordRules::Rule.define_rule(<<~RULE)
        rule farewell
          Salutation(greeting, farewell)
          Person(name, greetable = true)
          Person(name, farewellable = true)
        on match
          TestHelper.matches += [[greeting, name]]
          TestHelper.matches += [[farewell, name]]
        on unmatch
          TestHelper.matches -= [[greeting, name]]
          TestHelper.matches -= [[farewell, name]]
      RULE

      TestHelper.matches = []
    end

    it "shares a Condition node" do
      expect(ActiveRecordRules::Condition.all.size).to be == 3
    end

    context "with ten people" do
      before do
        Salutation.create!(greeting: "What's up?")
        10.times do |i|
          Person.create!(name: "Person #{i}")
        end
        Person.create!(name: "John", greetable: true)
      end

      it "only processes a single Person when one is added" do
        capturing_logs do |output|
          Person.create!(name: "Jane", greetable: true)
          expect(output.string.scan(/Person\(([0-9]+)\)/).uniq).to contain_exactly(["12"])
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
      ActiveRecordRules::Rule.define_rule(<<~RULE)
        rule greet
          Salutation(greeting)
          Person(name = name1)
          Person(name = name2, name > name1)
        on match
          # puts "match \#{greeting}/\#{name1}/\#{name2}"
          TestHelper.matches += [[greeting, name1, name2]]
        on unmatch
          # puts "unmatch \#{greeting}/\#{name1}/\#{name2}"
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
      ActiveRecordRules::Rule.define_rule(<<~RULE)
        rule greet
          Salutation(greeting)
          Person(name = name1, greetable = true)
          Person(name = name2, name > name1)
        on match
          # puts "match \#{greeting}/\#{name1}/\#{name2}"
          TestHelper.matches += [[greeting, name1, name2]]
        on unmatch
          # puts "unmatch \#{greeting}/\#{name1}/\#{name2}"
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

  describe "rules referencing non-Fact classes" do
    it "fails if the class is not a Fact" do
      expect { ActiveRecordRules::Rule.define_rule(<<~RULE) }.to raise_error(ActiveRecord::RecordInvalid)
        rule fail at defining
          NonFact()
      RULE
    end
  end
end
