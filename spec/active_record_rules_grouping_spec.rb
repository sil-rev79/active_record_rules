# frozen_string_literal: true

RSpec.describe ActiveRecordRules do
  define_record "Course" do |t|
    t.string :student_names
    t.integer :early_rego_count
    t.integer :early_cutoff
  end

  define_record "Student" do |t|
    t.string :name
    t.string :status
  end

  define_record "CourseStudent" do |t|
    t.references :course, null: false
    t.references :student, null: false
    t.integer :rego_time

    belongs_to :course
    belongs_to :student
  end

  describe "count" do
    before do
      # Create a bunch of extra courses, to make this test much slower
      # without optimisations.
      (1..500).each do |i|
        Course.create!(early_cutoff: i)
      end

      described_class.define_rule("Reify student counts on classes") do
        later(<<~MATCH)
          Course(id = <course_id>, <early_cutoff>)
          <count> = count(<student_id>) {
            CourseStudent(<course_id>, <student_id>, rego_time < <early_cutoff>)
            Student(id = <student_id>, status = "active")
          }
        MATCH
        on_match do
          Course.update(course_id, early_rego_count: count)
        end
      end
    end

    let(:course) { Course.create!(early_cutoff: 10) }
    let(:student) { Student.create!(name: "John Doe", status: "active") }

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

  describe "array aggregation" do
    let(:course) { Course.create! }
    let(:student) { Student.create!(name: "John Doe", status: "active") }

    before do
      described_class.define_rule("Reify student names on classes") do
        later(<<~MATCH)
          Course(id = <course_id>)
          <names> = array(<name>) {
            CourseStudent(<course_id>, <student_id>)
            Student(id = <student_id>, <name>)
          }
        MATCH
        on_match do
          Course.update(course_id, student_names: names.sort.join(", "))
        end
      end
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

  describe "array aggregation with tuples" do
    let(:course) { Course.create! }
    let(:student) { Student.create!(name: "John Doe", status: "active") }

    before do
      described_class.define_rule("Reify student names on classes") do
        later(<<~MATCH)
          Course(id = <course_id>)
          <ids_and_names> = array([<student_id>, <name>]) {
            # CourseStudent(<course_id>, <student_id>)
            Student(id = <student_id>, <name>)
            any {
              CourseStudent(<course_id>, <student_id>)
            }
          }
        MATCH

        on_match do
          Course.update(course_id, student_names: ids_and_names.sort.join(", "))
        end
      end
    end

    it "sets an empty course to the empty string" do
      expect(course.reload.student_names).to eq ""
    end

    context "with a student in the course" do
      let!(:course_student) { CourseStudent.create(course: course, student: student) }

      it "includes the student's name" do
        expect(course.reload.student_names).to eq "1, John Doe"
      end

      it "does not include the student's name after removing them" do
        course_student.destroy!
        expect(course.reload.student_names).to eq ""
      end
    end
  end
end
