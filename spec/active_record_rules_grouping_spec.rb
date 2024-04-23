# frozen_string_literal: true

class CourseStudent < TestRecord
  belongs_to :course
  belongs_to :student
end

class Course < TestRecord; end
class Student < TestRecord; end

RSpec.describe ActiveRecordRules do
  before do
    define_tables do |schema|
      schema.create_table :courses do |t|
        t.string :student_names
        t.integer :early_rego_count
        t.integer :early_cutoff
      end
      schema.create_table :students do |t|
        t.string :name
      end
      schema.create_table :course_students do |t|
        t.references :course
        t.references :student
        t.integer :rego_time
      end
    end
  end

  describe "count" do
    before do
      described_class.define_rule <<~RULE
        rule Reify student counts on classes
          Course(id = <course_id>, <early_cutoff>)
          <count> = count(<student_id>) {
            CourseStudent(<course_id>, <student_id>, rego_time < <early_cutoff>)
            Student(id = <student_id>)
          }
        on match
          Course.update(course_id, early_rego_count: count)
      RULE
    end

    let(:course) { Course.create!(early_cutoff: 10) }
    let(:student) { Student.create!(name: "John Doe") }

    it "sets the number of things to zero" do
      expect(course.reload.early_rego_count).to eq 0
    end

    context "with a student in the course early" do
      let!(:course_student) { CourseStudent.create(course: course, student: student, rego_time: 3) }

      it "includes the student in the count" do
        expect(course.reload.early_rego_count).to eq 1
      end

      it "does not include the student in the count after removing them" do
        course_student.destroy!
        expect(course.reload.early_rego_count).to eq 0
      end

      it "does not include the student in the count if their rego time is updated to be later" do
        course_student.update!(rego_time: 13)
        expect(course.reload.early_rego_count).to eq 0
      end
    end

    context "with a student in the course after the early cutoff" do
      let!(:course_student) { CourseStudent.create(course: course, student: student, rego_time: 15) }

      it "does not include the student in the count" do
        expect(course.reload.early_rego_count).to eq 0
      end

      it "includes the student in the count if their rego time is updated to be earlier" do
        course_student.update!(rego_time: 5)
        expect(course.reload.early_rego_count).to eq 1
      end
    end
  end

  describe "array aggregation", restrict_database: :postgres do
    let(:course) { Course.create! }
    let(:student) { Student.create!(name: "John Doe") }

    before do
      described_class.define_rule <<~RULE
        rule Reify student names on classes
          Course(id = <course_id>)
          <names> = array(<name>) {
            CourseStudent(<course_id>, <student_id>)
            Student(id = <student_id>, <name>)
          }
        on match
          Course.update(course_id, student_names: names.sort.join(', '))
      RULE
    end

    it "sets an empty course to the empty string" do
      expect(course.reload.student_names).to eq ""
    end

    context "with a student in the course" do
      let!(:course_student) { CourseStudent.create(course: course, student: student) }

      it "includes the student's name" do
        expect(course.reload.student_names).to eq "John Doe"
      end

      it "does not include the student's name after removing them" do
        course_student.destroy!
        expect(course.reload.student_names).to eq ""
      end
    end
  end
end
