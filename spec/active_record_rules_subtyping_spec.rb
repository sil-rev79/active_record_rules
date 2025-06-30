# frozen_string_literal: true

RSpec.describe ActiveRecordRules do
  define_record "Vehicle" do |t|
    t.string :type
    t.string :name
  end

  define_record "Passenger" do |t|
    t.references :vehicle
    t.string :name
  end

  before do
    stub_const("Car", Class.new(Vehicle))
    stub_const("Bus", Class.new(Vehicle))
  end

  describe "a rule on vehicles" do
    before do
      described_class.define_rule("list passengers") do
        later(<<~MATCH)
          Vehicle(<id>, <name>)
          Passenger(vehicle_id = <id>, name = <passenger>)
        MATCH
        on_match do
          TestHelper.matches += [[name, passenger]]
        end
        on_unmatch do
          TestHelper.matches -= [[name, passenger]]
        end
      end

      TestHelper.matches = []
    end

    context "with a car and a passanger" do
      let!(:car) { Car.create!(name: "Sheila") }
      let!(:passenger) { Passenger.create!(name: "John", vehicle_id: car.id) }

      it "matches the create" do
        expect(TestHelper.matches).to include(["Sheila", "John"])
      end

      it "matches an update to the car name" do
        car.update!(name: "Betsy")
        expect(TestHelper.matches).to include(["Betsy", "John"])
      end

      it "matches an update to the passenger name" do
        passenger.update!(name: "Jonas")
        expect(TestHelper.matches).to include(["Sheila", "Jonas"])
      end
    end

    context "with a bus and a passanger" do
      let!(:bus) { Bus.create!(name: "357") }
      let!(:passenger) { Passenger.create!(name: "John", vehicle_id: bus.id) }

      it "matches" do
        expect(TestHelper.matches).to include(["357", "John"])
      end

      it "matches an update to the bus name" do
        bus.update!(name: "406")
        expect(TestHelper.matches).to include(["406", "John"])
      end

      it "matches an update to the passenger name" do
        passenger.update!(name: "Jonas")
        expect(TestHelper.matches).to include(["357", "Jonas"])
      end
    end
  end
end
