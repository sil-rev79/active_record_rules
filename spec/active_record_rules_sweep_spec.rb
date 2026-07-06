# frozen_string_literal: true

RSpec.describe ActiveRecordRules do
  define_record "Person" do |t|
    t.string :name
  end

  before do
    described_class.define_rule("greet people") do
      later("Person(<name>)")
      on_match do
        TestHelper.matches += [ name ]
      end
    end

    TestHelper.matches = []
  end

  describe ".sweep_stranded_matches" do
    # Simulate a "later" execution job that was lost (e.g. the job
    # runner was hard-killed after the activation ran but before the
    # execution ran): the match is left with queued_since set, and
    # nothing will ever execute it.
    def strand_queued_match!(age: 20.minutes)
      ActiveJob::Base.queue_adapter.perform_enqueued_jobs = false
      yield
      perform_enqueued_jobs(only: ActiveRecordRules::Jobs::ActivateRules)
      ActiveRecordRules::RuleMatch.update_all(queued_since: Time.now - age)
    end

    it "re-drives a queued match whose execution job was lost" do # rubocop:disable RSpec/MultipleExpectations
      strand_queued_match! { Person.create!(name: "John") }
      expect(TestHelper.matches).to be_empty # nothing ran the match

      described_class.sweep_stranded_matches(rules: "greet people")

      expect(TestHelper.matches).to include("John")
    end

    # Simulate an execution which crashed mid-run without even
    # marking the match as failed (e.g. the whole worker process was
    # killed): the match was claimed (running_since set, queued_since
    # cleared) but execution never finished, so running_since is left
    # set forever and claiming refuses to touch it again.
    def strand_running_match!(age: 20.minutes)
      strand_queued_match! { yield }
      ActiveRecordRules::Rule.claim_pending_executions!(ActiveRecordRules::RuleMatch.pluck(:id))
      ActiveRecordRules::RuleMatch.update_all(running_since: Time.now - age)
    end

    it "recovers and re-drives a match stuck mid-execution" do # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
      strand_running_match! { Person.create!(name: "John") }
      expect(TestHelper.matches).to be_empty # nothing finished the match

      described_class.sweep_stranded_matches(rules: "greet people")

      expect(TestHelper.matches).to include("John")
      match = ActiveRecordRules::RuleMatch.sole
      expect(match.running_since).to be_nil
    end

    context "with a second rule matching the same records" do
      before do
        described_class.define_rule("farewell people") do
          later("Person(<name>)")
          on_match do
            TestHelper.matches += [ "farewell:#{name}" ]
          end
        end
      end

      it "does not touch matches for rules that were not named" do # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
        strand_queued_match! { Person.create!(name: "John") }

        described_class.sweep_stranded_matches(rules: "greet people")

        expect(TestHelper.matches).to eq([ "John" ])
        farewell_match = ActiveRecordRules::RuleMatch
          .find_by(rule_id: described_class.find_rule("farewell people").id)
        expect(farewell_match.queued_since).not_to be_nil
      end

      it "sweeps every loaded rule when given :all" do
        strand_queued_match! { Person.create!(name: "John") }

        described_class.sweep_stranded_matches(rules: :all)

        expect(TestHelper.matches).to contain_exactly("John", "farewell:John")
      end
    end

    it "leaves recently-queued matches alone" do
      strand_queued_match!(age: 1.minute) { Person.create!(name: "John") }

      described_class.sweep_stranded_matches(rules: "greet people")

      expect(TestHelper.matches).to be_empty
    end

    it "leaves recently-started executions alone" do # rubocop:disable RSpec/MultipleExpectations
      strand_running_match!(age: 1.minute) { Person.create!(name: "John") }

      described_class.sweep_stranded_matches(rules: "greet people")

      expect(TestHelper.matches).to be_empty
      expect(ActiveRecordRules::RuleMatch.sole.running_since).not_to be_nil
    end

    it "does not re-drive failed matches" do
      strand_queued_match! { Person.create!(name: "John") }
      ActiveRecordRules::RuleMatch.update_all(queued_since: nil, failed_since: Time.now)

      described_class.sweep_stranded_matches(rules: "greet people")

      expect(TestHelper.matches).to be_empty
    end

    # A failed unmatch leaves BOTH failed_since and running_since set
    # (unlike a failed match, which clears running_since). Recovery
    # must not mistake it for a crashed execution: it has failed, and
    # failures need human attention.
    it "does not recover matches which failed mid-unmatch" do # rubocop:disable RSpec/MultipleExpectations
      strand_running_match! { Person.create!(name: "John") }
      ActiveRecordRules::RuleMatch.update_all(failed_since: Time.now)

      described_class.sweep_stranded_matches(rules: "greet people")

      expect(TestHelper.matches).to be_empty
      expect(ActiveRecordRules::RuleMatch.sole.running_since).not_to be_nil
    end

    it "raises for a rule which is not loaded" do
      expect do
        described_class.sweep_stranded_matches(rules: "no such rule")
      end.to raise_error(ArgumentError, /no such rule/)
    end
  end
end
