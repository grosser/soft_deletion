require 'active_record'
require 'soft_deletion/version'
require 'soft_deletion/core'
require 'soft_deletion/dependency'
require 'soft_deletion/relation'
require 'soft_deletion/setup'

ActiveRecord::Base.send(:include, SoftDeletion::Setup)
