# frozen_string_literal: true

require "active_record_rules/clause"

RSpec.describe ActiveRecordRules::Clause do
  describe "parsing" do
    subject { described_class.parse(input).unparse }

    {
      "<abc>" => "abc = <abc>",
      "x=<y>" => "x = <y>",
      "<x>=y" => "<x> = y",
      'x="x"' => 'x = "x"',
      '"x"=<x>' => '"x" = <x>',
      "x=9" => "x = 9",
      "9=x" => "9 = x",
      "x=true" => "x = true",
      "false=<x>" => "false = <x>",
      "x=nil" => "x = nil",
      "<x>=y+1" => "<x> = y + 1"
    }.each do |input, output|
      context "with input {#{input}}" do
        let(:input) { input }

        it { is_expected.to eq(output) }
      end
    end
  end

  describe "extracting record variables" do
    subject { described_class.parse(input).record_variables }

    {
      "<abc>" => ["abc"],
      "x=<y>" => ["x"],
      "<x>=y" => ["y"],
      'x="x"' => ["x"],
      '"x"=<x>' => [],
      "x=9" => ["x"],
      "9=x" => ["x"],
      "x=true" => ["x"],
      "false=<x>" => [],
      "x=nil" => ["x"]
    }.each do |input, output|
      context "with input {#{input}}" do
        let(:input) { input }

        it { is_expected.to eq(Set.new(output)) }
      end
    end
  end
end
