# encoding: utf-8
# author: Boris Barroso
# email: boriscyber@gmail.com
class PayPlan < ActiveRecord::Base
  acts_as_org
  after_initialize :set_defaults
  before_save :set_currency_id
  before_destroy :check_if_paid
  #after_save :update_transaction
  #after_save :update_transaction_payment_date
  #after_destroy :update_transaction
  
  # attr accesor 
  attr_protected :pivot

  STATES = ["valid", "delayed", "payed"]

  # relationships
  belongs_to :transaction
  belongs_to :currency

  # delegations
  delegate :currency_id, :pay_plans_balance, :pay_plans_total, :payment_date, :real_state, :paid?, :cash, :ref_number, :draft?, :balance, :state,
    :to => :transaction, :prefix => true
  delegate :name, :symbol, :to => :currency, :prefix => true

  # validations
  validate :valid_income_or_interests_penalties_filled
  validate :valid_pay_plans_total_amount
  validates_presence_of :payment_date, :alert_date

  # scopes
  scope :unpaid, where(:paid => false)

  def self.pivot
    where(:pivot => true).first
  end

  # Returns the current state of the payment
  def state
    if paid?
      "Pagado"
    elsif payment_date < Date.today
      "Atrasado"
    else
      "Válido"
    end
  end

  # override the to_json
  def to_json
    self.attributes.merge(
      :transaction_payment_date => transaction_payment_date,
      :transaction_real_state => transaction_real_state,
      :transaction_cash => transaction_cash
    ).to_json
  end

private
  # checks if income or interests_penalties is filled
  def valid_income_or_interests_penalties_filled
    if amount <= 0 and interests_penalties <= 0
      errors.add(:amount, "Cantidad o Intereses/Penalidades debe ser mayor a 0")
    end
  end

  def set_defaults
    self.amount ||= self.transaction_pay_plans_balance
    self.interests_penalties ||= 0.0
    self.payment_date ||= Date.today
    self.alert_date ||= self.payment_date - 5.days
    self.currency_id ||= transaction_currency_id
  end

  def set_currency_id
    self.currency_id = self.transaction_currency_id
  end

  def get_transaction_cash
    if self.destroyed?
      PayPlan.unpaid.where(:transaction_id => transaction_id).size <= 0
    else
      false
    end
  end

  #############################3
  # Transaction methods

  # returns the payment_date for the transaction
  def get_transaction_payment_date
    pp = PayPlan.unpaid.where(:transaction_id => transaction_id)
    if pp.size > 0
      pp.order("payment_date ASC").limit(1).first.payment_date
    else
      nil
    end
  end

  # updates transaction data
  #def update_transaction
  #  unless transaction_pay_plans_balance == transaction_balance
  #    return false unless create_pay_plan_to_complete_transaction
  #  end
  #  transaction.set_trans(false)
  #  transaction.cash = false if transaction_state == 'draft'
  #  transaction.payment_date = get_transaction_payment_date || Date.today
  #  transaction.save
  #end

  ## Creates a pay_plan to complete the balance for the transaction
  #def create_pay_plan_to_complete_transaction
  #  pp = transaction.new_pay_plan(:amount => transaction_pay_plans_balance, :payment_date => payment_date + 1.day, :alert_date => alert_date + 1.day)
  #  pp.save
  #end

  #################

  # Checks that all pay_plans amounts sum <= transaction.total
  def valid_pay_plans_total_amount
    pivot_amount = 0
    piv = transaction.pay_plans.pivot
    if piv
      pivot_amount = piv.amount
    end

    if amount > (transaction.pay_plans_balance + pivot_amount)
      self.errors.add(:amount, "La cantidad que ingreso supera al total de la Nota de #{transaction.type_translated}")
    end
  end

  # checks if the pay_plan has been paid
  def check_if_paid
    if paid?
      if transaction.class == "Income"
        text = "El plan de cobro ya fue cobrado"
      else
        text = "El plan de pago ya pue pagado"
      end
      self.errors.add(:base, text)
      text
    end
  end
end
