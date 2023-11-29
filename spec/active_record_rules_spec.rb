# frozen_string_literal: true

require "parslet/convenience"

class Salutation < ActiveRecord::Base; include ActiveRecordRules::Fact; end
class Person < ActiveRecord::Base; include ActiveRecordRules::Fact; end

module TestHelper
  cattr_accessor :activated
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
      end
    end
  end

  context "with no constraints" do
    before do
      ActiveRecordRules::Rule.create_from_definition(<<~RULE)
        rule greet
          Salutation(greeting)
          Person(name)
        on activation
          # puts "activate \#{greeting}/\#{name}"
          TestHelper.activated += [[greeting, name]]
        on deactivation
          # puts "deactivate \#{greeting}/\#{name}"
          TestHelper.activated -= [[greeting, name]]
      RULE

      TestHelper.activated = []
    end

    let!(:salutation) { Salutation.create!(greeting: "hello") }

    context "with John as a person" do
      let!(:john) { Person.create!(name: "John") }

      it "activates for hello/John" do
        expect(TestHelper.activated).to include(["hello", "John"])
      end

      it "deactivates when John is deleted" do
        john.destroy!
        expect(TestHelper.activated).not_to include(["hello", "John"])
      end

      it "deactivates when John changes name" do
        john.update!(name: "Johns")
        expect(TestHelper.activated).not_to include(["hello", "John"])
      end

      it "activates for the new value when John changes name" do
        john.update!(name: "Johns")
        expect(TestHelper.activated).to include(["hello", "Johns"])
      end

      it "does nothing when an unrelated attributes changes" do
        salutation.update!(farewell: "goodbye")
        expect(TestHelper.activated).to include(["hello", "John"])
      end
    end

    context "with John and Jane as people" do
      before { Person.create!(name: "John") }

      let!(:jane) { Person.create!(name: "Jane") }

      it "activates for hello/Jane" do
        expect(TestHelper.activated).to include(["hello", "Jane"])
      end

      it "deactivates when Jane is deleted" do
        jane.destroy!
        expect(TestHelper.activated).not_to include(["hello", "Jane"])
      end
    end
  end

  context "with constraints between three conditions" do
    before do
      ActiveRecordRules::Rule.create_from_definition(<<~RULE)
        rule greet
          Salutation(greeting)
          Person(name = name1)
          Person(name = name2, name > name1)
        on activation
          # puts "activate \#{greeting}/\#{name1}/\#{name2}"
          TestHelper.activated += [[greeting, name1, name2]]
        on deactivation
          # puts "deactivate \#{greeting}/\#{name1}/\#{name2}"
          TestHelper.activated -= [[greeting, name1, name2]]
      RULE

      TestHelper.activated = []
    end

    describe "adding two people, then a salutation" do
      let!(:john) { Person.create!(name: "John") }

      before do
        Person.create!(name: "Jane")
        Salutation.create!(greeting: "hello")
      end

      it "does not activate twice" do
        expect(TestHelper.activated).to contain_exactly(["hello", "Jane", "John"])
      end

      it "deactivates properly" do
        john.destroy!
        expect(TestHelper.activated).to be_empty
      end
    end
  end
end
