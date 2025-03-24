require 'bundler/setup'

require 'single_cov'
SingleCov.setup :rspec

require 'soft_deletion'
require 'database_cleaner'
require 'logger'

if ActiveRecord::VERSION::STRING > "7.1.0"
  ActiveRecord.deprecator.behavior = lambda { |message, _callback| raise message }
  ActiveRecord.deprecator.silenced = false
else
  ActiveSupport::Deprecation.behavior = lambda { |message, _callback| raise message }
  ActiveSupport::Deprecation.silenced = false
end
# ActiveRecord::Base.logger = Logger.new(STDOUT) # for easier debugging

RSpec.configure do |config|
  config.before do
    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean
  end
end

def clear_callbacks(model, callback)
  model.reset_callbacks callback
end

# connect
ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database => ":memory:"
)

# create tables
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define(:version => 1) do
  create_table :forums do |t|
    t.integer :category_id
    t.integer :organization_id
    t.timestamp :deleted_at
  end

  create_table :categories do |t|
    t.timestamp :deleted_at
    t.timestamp :updated_at
  end

  create_table :original_categories do |t|
  end

  create_table :counter_cache_categories do |t|
    t.integer :forums_count, null: false, default: 0
    t.timestamp :deleted_at
  end
end

# setup models

class Forum < ActiveRecord::Base
  attr_accessor :fail_validations
  has_soft_deletion

  belongs_to :category

  validate :fail_validation_not_set

  private

  def fail_validation_not_set
    errors.add(:base, 'foo') if fail_validations
  end
end

class ValidatedForum < ActiveRecord::Base
  self.table_name = 'forums'

  has_soft_deletion

  belongs_to :category
  validates_presence_of :category_id
end

class Category < ActiveRecord::Base
  has_soft_deletion

  has_many :forums, :dependent => :destroy
end

class Organization < ActiveRecord::Base
  self.table_name = 'categories'
  has_soft_deletion

  has_many :forums, :dependent => :nullify
end

class CategoryWithDefault < ActiveRecord::Base
  self.table_name = 'categories'
  has_soft_deletion default_scope: true

  has_many :forums, class_name: 'Cat2Forum', foreign_key: :category_id
end

# No association
class NACategory < ActiveRecord::Base
  self.table_name = 'categories'

  has_soft_deletion
end

# Independent association
class IDACategory < ActiveRecord::Base
  self.table_name = 'categories'

  has_soft_deletion

  has_many :forums, :dependent => :destroy, :foreign_key => :category_id
end

# Nullified dependent association
class NDACategory < ActiveRecord::Base
  self.table_name = 'categories'

  has_soft_deletion

  has_many :forums, :dependent => :nullify, :foreign_key => :category_id
end

# Delete dependent association
class DDACategory < ActiveRecord::Base
  self.table_name = 'categories'

  has_soft_deletion

  has_many :forums, :dependent => :delete_all, :foreign_key => :category_id
end

# default dependent association
class XDACategory < ActiveRecord::Base
  self.table_name = 'categories'

  has_soft_deletion

  has_many :forums, :foreign_key => :category_id
end

# Has ome association
class HOACategory < ActiveRecord::Base
  self.table_name = 'categories'

  has_soft_deletion

  has_one :forum, :dependent => :destroy, :foreign_key => :category_id
end

# Class without column deleted_at
class OriginalCategory < ActiveRecord::Base
  has_soft_deletion
end

# Has many Destroyable Association
class DACategory < ActiveRecord::Base
  self.table_name = 'categories'

  has_soft_deletion

  has_many :destroyable_forums, :dependent => :destroy, :foreign_key => :category_id
end

# Forum that isn't soft deletable for association checking
class DestroyableForum < ActiveRecord::Base
  self.table_name = 'forums'
end

# test that it does not blow up when the table is not yet defined (e.g. in rake db:reset)
class NoTable < ActiveRecord::Base
  has_soft_deletion
end

# Forum with other default scope
class Cat1Forum < ActiveRecord::Base
  self.table_name = 'forums'

  has_soft_deletion
  default_scope { where(:category_id => 1) }

  belongs_to :category
end

class Cat2Forum < ActiveRecord::Base
  self.table_name = 'forums'

  has_soft_deletion :default_scope => true
end

class Cat2ForumChild < Cat2Forum
  self.table_name = 'forums'
end

# Counter cache Forum
class CCForum < ActiveRecord::Base
  self.table_name = 'forums'

  has_soft_deletion

  belongs_to :category, class_name: 'CCCategory', foreign_key: 'category_id', counter_cache: :forums_count
end

# Counter cache category
class CCCategory < ActiveRecord::Base
  self.table_name = 'counter_cache_categories'

  has_soft_deletion

  has_many :forums, class_name: 'CCForum', primary_key: 'id', foreign_key: 'category_id'
end

class TimestampCategory  < ActiveRecord::Base
  self.table_name = 'categories'

  has_soft_deletion(update_timestamp: :updated_at)
end
