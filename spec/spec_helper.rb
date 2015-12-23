require 'soft_deletion'
require 'database_cleaner'
require 'logger'

ActiveSupport::Deprecation.behavior = lambda { |message, _callback| raise message }
ActiveSupport::Deprecation.silenced = false
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
  end

  create_table :original_categories do |t|
  end
end

# setup models

class Forum < ActiveRecord::Base
  has_soft_deletion

  belongs_to :category
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

# Has many destroyable association
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
  if ActiveRecord::VERSION::MAJOR >= 4
    default_scope { where(:category_id => 1) }
  else
    default_scope :conditions => {:category_id => 1}
  end

  belongs_to :category
end

class Cat2Forum < ActiveRecord::Base
  self.table_name = 'forums'

  has_soft_deletion :default_scope => true
end
