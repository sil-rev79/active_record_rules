# # frozen_string_literal: true

# class CourseStudent < TestRecord; end
# class Course < TestRecord; end
# class Student < TestRecord; end

# RSpec.describe ActiveRecordRules do
#   before do
#     define_tables do |schema|
#       schema.create_table :courses do |t|
#         t.string :student_names
#       end
#       schema.create_table :students do |t|
#         t.string :name
#       end
#       schema.create_table :course_students do |t|
#         t.references :courses
#         t.references :students
#       end
#     end

#     described_class.define_rule <<~RULE
#       rule Reify student names on classes
#         Course(id = <course_id>)
#         <names> = array(<name>) {
#           CourseStudent(<course_id>, <student_id>)
#           Student(id = <student_id>, <name>)
#         }
#       on match
#         Course.update(course_id, student_names: names.sort.join(', '))
#     RULE
#   end

#   describe "examples" do
#     let!(:course) { Course.create! }
#     let(:student) { Student.create!(name: "John doe") }

#     it "sets an empty course to the empty string" do
#       expect(course.reload.student_names).to eq ""
#     end

#     context "with a student in the course" do
#       let!(:course_student) { CourseStudent.create(course: course, student: student) }

#       it "includes the student's name" do
#         expect(course.reload.student_names).to eq "John Doe"
#       end

#       it "does not include the student's name after removing them" do
#         course_student.destroy!
#         expect(course.reload.student_names).to eq ""
#       end
#     end
#   end

#   # describe "properties" do
#   #   context "with no duplicate times" do
#   #     generate(times: array(int(0..100), length: 1..).map(&:uniq))

#   #     before do
#   #       # We want to avoid triggering on each rule, to avoid making
#   #       # this test take forever. Since we work on the database level,
#   #       # we can use a different Ruby model and it still works.
#   #       times.each { RacerNoTrigger.create!(race_time: _1) }
#   #       described_class.trigger_all(Racer)
#   #     end

#   #     it_always "has a single winner" do
#   #       expect(Racer.where(winner: true).size).to eq(1)
#   #     end
#   #   end
#   # end
# end
