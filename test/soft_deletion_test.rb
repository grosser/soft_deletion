require 'test/unit'

require 'test/unit/ui/console/testrunner'

Test::Unit::UI::Console::TestRunner.class_eval do
  alias_method :attach_to_mediator_without_fix, :attach_to_mediator

  def attach_to_mediator
    attach_to_mediator_without_fix
    @mediator.add_listener(Test::Unit::TestCase::STARTED, &method(:test_started))
    @mediator.add_listener(Test::Unit::TestCase::FINISHED, &method(:test_finished))
  end
end

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
