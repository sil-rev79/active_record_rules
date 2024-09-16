# frozen_string_literal: true

class Classroom < TestRecord
  has_many :teachers
end

class Teacher < TestRecord; end

RSpec.describe ActiveRecordRules do
  before do
    define_tables do |schema|
      schema.create_table :classrooms

      schema.create_table :teachers do |t|
        t.string :name
        t.references :classroom
      end
    end

    described_class.define_rule(<<~RULE)
      after request rule: a classroom with no teachers gets John
        Classroom(<id>)
        not { Teacher(classroom_id = <id>) }
      on match
        Teacher.create!(name: "John", classroom_id: id)
    RULE

    described_class.define_rule(<<~RULE)
      after request rule: a classroom with other teachers loses John
        Classroom(<id>)
        Teacher(<john_id> = id, classroom_id = <id>, name = "John")
        Teacher(classroom_id = <id>, name != "John")
      on match
        Teacher.find(john_id).destroy!
    RULE
  end

  describe "not calling wrap_request" do
    let(:classroom) { Classroom.create! }

    context "with an empty classroom" do
      it "adds John straight away" do
        expect(classroom.teachers.pluck(:name)).to contain_exactly("John")
      end
    end

    context "when another teacher is added" do
      before { Teacher.create!(name: "Stacey", classroom_id: classroom.id) }

      it "removes John straight away" do
        expect(classroom.teachers.pluck(:name)).not_to contain_exactly("John")
      end
    end
  end

  describe "calling wrap_request" do
    let(:classroom) { Classroom.create! }

    it "adds John at the end of the request" do # rubocop:disable RSpec/MultipleExpectations
      described_class.wrap_request do
        expect(classroom.teachers.pluck(:name)).not_to contain_exactly("John")
      end
      expect(classroom.teachers.pluck(:name)).to contain_exactly("John")
    end

    it "doesn't add John when another teacher is added first" do # rubocop:disable RSpec/MultipleExpectations
      described_class.wrap_request do
        Teacher.create!(name: "Stacey", classroom_id: classroom.id)
        expect(classroom.teachers.pluck(:name)).to contain_exactly("Stacey")
      end
      expect(classroom.teachers.pluck(:name)).not_to contain_exactly("John")
    end
  end
end
