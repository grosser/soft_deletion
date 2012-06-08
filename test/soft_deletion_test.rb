require 'test/unit'

require 'test/unit/ui/console/testrunner'
require 'test/unit/active_support'
require 'active_support/test_case'

class SoftDeletionTest < ActiveSupport::TestCase
  def test_xxx
    assert_equal 1, 1
  end

  def test_xxxsd
    assert_equal 1, 1
  end

  def test_xxxx
    assert_equal 1, 1
  end

  def test_xxxx32
    assert_equal 1, 1
  end

  def test_xxxx5556
    assert_equal 1, 2
  end
end
