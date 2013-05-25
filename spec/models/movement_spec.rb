require 'spec_helper'

describe Movement do


  context "#can_null?" do
    let(:subject) {
      m = Movement.new(amount: 100, state: 'draft')
      m.build_transaction
      m.total =  100
      m
    }

    it { should be_is_draft }
    # draft
    it { should be_can_null }

    it "diferent total" do
      subject.balance = 90

      subject.should_not be_can_null
    end

    it "pendent_ledgers" do
      subject.stub_chain(:ledgers, :pendent, empty?: false)

      subject.should_not be_can_null
    end

    it "is_nulled" do
      subject.state = 'nulled'

      subject.should_not be_can_null
    end

    # Can null
    it "approved" do
      subject.state = 'approved'
      subject.should be_is_approved

      subject.should be_can_null
    end
  end
end