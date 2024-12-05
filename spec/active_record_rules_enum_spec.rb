# frozen_string_literal: true

class WorkOrder < TestRecord
  enum status: {
    pending_approval: 0,
    rejected: 1,
    approved: 2
  }
end

class WorkOrderApproval < TestRecord
  enum status: {
    pending: 0,
    rejected: 1,
    approved: 2
  }
end

RSpec.describe ActiveRecordRules do
  before do
    define_tables do |schema|
      schema.create_table :work_orders do |t|
        t.integer :status
      end

      schema.create_table :work_order_approvals do |t|
        t.references :work_order
        t.integer :status
      end
    end
  end

  describe "using enums as strings" do
    before do
      described_class.define_rule("A pending work order has a pending approval") do
        after_commit(<<~MATCH)
          WorkOrder(<id>, status:s = "pending_approval")
        MATCH

        on_match do
          WorkOrderApproval.create!(work_order_id: id, status: "pending")
        end
      end
    end

    let(:work_order) { WorkOrder.create!(status: "pending_approval") }

    it "creates a work order approval" do
      expect(WorkOrderApproval.find_by(work_order_id: work_order.id).status).to eq("pending")
    end
  end

  describe "bindings enums as strings" do
    before do
      described_class.define_rule("A pending work order has a pending approval") do
        later(<<~MATCH)
          WorkOrder(<id>, <status:s>)
          <status> = "pending_approval"
        MATCH

        on_match do
          WorkOrderApproval.create!(work_order_id: id, status: "pending")
        end
      end
    end

    let(:work_order) { WorkOrder.create!(status: "pending_approval") }

    it "creates a work order approval" do
      expect(WorkOrderApproval.find_by(work_order_id: work_order.id).status).to eq("pending")
    end
  end

  describe "using enums as integers" do
    before do
      described_class.define_rule("A pending work order has a pending approval") do
        later(<<~MATCH)
          WorkOrder(<id>, status:i = 0)
        MATCH
        on_match do
          WorkOrderApproval.create!(work_order_id: id, status: "pending")
        end
      end
    end

    let(:work_order) { WorkOrder.create!(status: "pending_approval") }

    it "creates a work order approval" do
      expect(WorkOrderApproval.find_by(work_order_id: work_order.id).status).to eq("pending")
    end
  end

  describe "binding enums as integers" do
    before do
      described_class.define_rule("A pending work order has a pending approval") do
        later(<<~MATCH)
          WorkOrder(<id>, <status:i>)
          <status> = 0
        MATCH
        on_match do
          WorkOrderApproval.create!(work_order_id: id, status: "pending")
        end
      end
    end

    let(:work_order) { WorkOrder.create!(status: "pending_approval") }

    it "creates a work order approval" do
      expect(WorkOrderApproval.find_by(work_order_id: work_order.id).status).to eq("pending")
    end
  end
end
