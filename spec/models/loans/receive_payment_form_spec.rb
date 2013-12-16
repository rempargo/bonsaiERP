require 'spec_helper'

describe Loans::ReceivePaymentForm do
  #it { should validate_presence_of(:reference) }

  let(:loan_attr) do
    today = Date.today
    {
      date: today, due_date: today + 10.days, total: 100,
      reference: 'Receipt 00232', contact_id: 1
    }
  end


  it "validate" do
    lp = Loans::PaymentForm.new
    lp.stub(loan: Loan.new(total: 100))
    lp.valid?
  end

  context 'payment' do
    let(:cash) { create :cash, currency: 'BOB', amount: 0 }
    let(:contact) { build :contact, id: 1 }


    let(:attributes) do
      {
        account_to_id: cash.id, date: Date.today, reference: 'Pay 23233',
        date: Date.today, amount: 50, exchange_rate: 1
      }
    end

    before(:each) {
      UserSession.user = build :user, id: 1
      OrganisationSession.organisation = build :organisation, currency: 'BOB'
      Loans::Receive.any_instance.stub(contact: contact)
    }

    it "pays Loan" do
      lf = Loans::ReceiveForm.new(loan_attr.merge(account_to_id: cash.id))

      lf.create.should be_true
      lf.loan.should be_persisted
      lf.loan.should be_is_a(Loans::Receive)
      lf.loan.amount.should == 100
      lf.loan.total.should == 100
      lf.loan.ledger_in.should be_is_a(AccountLedger)
      lf.loan.ledger_in.should be_is_lrcre
      cash.reload.amount.should == 100

      lp = Loans::ReceivePaymentForm.new(attributes.merge(account_id: lf.loan.id))

      lp.create_payment.should be_true
      lp.ledger.amount.should == -50

      loan = Loans::Receive.find(lf.loan.id)
      loan.amount.should == 50

      c = Cash.find(cash.id)
      c.amount.should == 50

      lp = Loans::ReceivePaymentForm.new(attributes.merge(account_id: lf.loan.id, amount: 60))
      lp.create_payment.should be_false
      lp.errors[:amount].should eq([I18n.t('errors.messages.less_than_or_equal_to', count: 50.0)])
      # Pay with other currency
      bank = create :bank, currency: 'USD', amount: 0

      lp = Loans::ReceivePaymentForm.new(attributes.merge(account_id: lf.loan.id, amount: 25, account_to_id: bank.id, exchange_rate: 2))

      lp.create_payment.should be_true
      loan = Loans::Receive.find(loan.id)

      loan.amount.should == 0
      loan.should be_is_paid
    end

    # Pay with income
    it "pay with income" do
      lf = Loans::ReceiveForm.new(loan_attr.merge(account_to_id: cash.id, total: 200))

      lf.create.should be_true
      lf.loan.amount.should == 200
      lf.loan.should be_is_approved

      today = Date.today
      income = Income.new(total: 100, balance: 100, state: 'approved', currency: 'BOB', id: 100, contact_id: 1,
                         date: today, due_date: today)
      income.stub(contact: build(:contact, id: 1))
      income.save.should be_true

      lp = Loans::ReceivePaymentForm.new(attributes.merge(account_id: lf.loan.id, amount: 200, account_to_id: income.id))

      # Validate for income amount
      lp.create_payment.should be_false
      lp.errors[:amount].should eq(['La cantidad es mayor que el saldo del Ingreso'])


      lp.amount = 100
      lp.create_payment.should be_true

      inc = Income.find(income.id)
      inc.amount.should == 0
      inc.should be_is_paid

      l = Loans::Receive.find(lf.loan.id)
      l.amount.should == 100
      l.should be_is_approved

      lp = Loans::ReceivePaymentForm.new(attributes.merge(account_id: lf.loan.id, amount: 200, account_to_id: cash.id))
      lp.create_payment.should be_false

      lp.errors[:amount].should_not be_blank
    end


    it "pays interest" do
      lf = Loans::ReceiveForm.new(loan_attr.merge(account_to_id: cash.id))

      lf.create.should be_true
      lf.loan.should be_persisted
      lf.loan.ledger_in.should be_is_a(AccountLedger)
      cash.reload.amount.should == 100

      lp = Loans::ReceivePaymentForm.new(attributes.merge(account_id: lf.loan.id))

      lp.create_interest.should be_true
      lp.int_ledger.amount.should == -50
      lp.int_ledger.should be_is_lrint
      lp.int_ledger.should be_persisted

      loan = Loans::Receive.find(lf.loan.id)
      loan.interests.should == 50

      c = Cash.find(cash.id)
      c.amount.should == 50
    end

    # Pay with INTERESTS with income
    it "pay INTERESTS with income" do
      lf = Loans::ReceiveForm.new(loan_attr.merge(account_to_id: cash.id, total: 200))

      lf.create.should be_true
      lf.loan.amount.should == 200
      lf.loan.should be_is_approved

      today = Date.today
      expense = Income.new(total: 100, balance: 100, state: 'approved', currency: 'BOB', id: 100, contact_id: 1,
                         date: today, due_date: today)
      expense.stub(contact: build(:contact, id: 1))
      expense.save.should be_true

      lp = Loans::ReceivePaymentForm.new(attributes.merge(account_id: lf.loan.id, amount: 200, account_to_id: expense.id))

      lp.create_interest.should be_false
      lp.amount = 100

      lp.create_interest.should be_true
      lp.int_ledger.should be_persisted
      lp.int_ledger.amount.should == -100
      lp.int_ledger.should be_is_lrint

      inc = Income.find(expense.id)
      inc.amount.should == 0
      inc.should be_is_paid

      # No changes to the amount
      l = Loans::Receive.find(lf.loan.id)
      l.amount.should == 200
      l.should be_is_approved
    end
  end

end
