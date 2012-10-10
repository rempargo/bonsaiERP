# encoding: utf-8
# author: Boris Barroso
# email: boriscyber@gmail.com
class Organisation < ActiveRecord::Base

  self.table_name = "common.organisations"

  DATA_PATH = "db/defaults"

  ########################################
  # Attributes
  attr_accessor :account_info, :email, :password
  attr_protected :base_accounts

  serialize :preferences, Hash

  attr_protected :user_id

  ########################################
  # Relationships
  belongs_to :org_country, :foreign_key => :country_id
  belongs_to :currency

  has_many :links, :dependent => :destroy, :autosave => true
  has_one  :master_link, class_name: 'Link', foreign_key: :organisation_id,
           conditions: { master_account: true, rol: 'admin' }

  has_many :users, through: :links, dependent: :destroy
  accepts_nested_attributes_for :users

  ########################################
  # Validations
  validates_presence_of   :name, :org_country, :currency, :tenant
  validates_uniqueness_of :name, :scope => :user_id
  validates :tenant, uniqueness: true, format: { with: /\A[a-z0-9]+\z/ }
  validate  :valid_tenant_not_in_list


  # Delegations
  delegate :code, :name, :symbol, :plural, :to => :currency, :prefix => true

  ########################################
  # Methods
  def to_s
    name
  end

  def build_master_account
    self.build_master_link.build_user
    self.master_link.creator = true
  end

  def create_organisation
    self.build_master_account
    user = master_link.user

    user.email = email
    user.password = password

    set_user_errors(user) unless user.valid?

    self.save
  end

  private
    def set_user_errors(user)
      self.errors[:email] = user.errors[:email] if user.errors[:email].present?
      self.errors[:password] = user.errors[:password] if user.errors[:password].present?
    end

    # Sets the expiry date for the organisation until ew payment
    def set_due_date
      self.due_date = 30.days.from_now.to_date
    end

    def valid_tenant_not_in_list
      if ['public', 'common', 'demo'].include?(tenant)
        self.errors[:tenant] << I18n.t('organisation.errors.tenant.list')
      end
    end
end
