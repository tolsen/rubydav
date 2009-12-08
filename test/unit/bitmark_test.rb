require 'lib/limestone/bitmark'
require 'test/unit/unit_test_helper'

class BitmarkTest < RubyDavUnitTestCase

  def test_compare
    assert_equal(0,
                 bmark('tag', 'yellow', 'tim') <=>
                 bmark('tag', 'yellow', 'tim'))

    assert_equal(0,
                 bmark('name', 'mybit', 'chetan', '/bitmarks/fakeuuid/foo') <=>
                 bmark('name', 'mybit', 'chetan', '/bitmarks/fakeuuid/foo'))

    assert_equal(1,
                 bmark('tag', 'yellow', 'tim') <=>
                 bmark('name', 'mybit', 'chetan', '/bitmarks/fakeuuid/foo'))

    assert_equal(-1,
                 bmark('tag', 'yellow', 'tim') <=>
                 bmark('yay', 'woohoo', 'paritosh'))

    assert_equal(1,
                 bmark('tag', 'blue', 'tim') <=>
                 bmark('tag', 'acidic', 'tim'))

    assert_equal(-1,
                 bmark('tag', 'yellow', 'chetan') <=>
                 bmark('tag', 'yellow', 'tim'))
  end

  def test_compare__same_except_one_url_nil
    assert_equal(-1, bmark('a', 'b', 'c') <=> bmark('a', 'b', 'c', 'd'))
    assert_equal(1, bmark('a', 'b', 'c', 'd') <=> bmark('a', 'b', 'c'))
  end
    
  def test_initialize__with_url
    bm = bmark 'tag', 'yellow', 'tim'
    assert_equal 'tag', bm.name
    assert_equal 'yellow', bm.value
    assert_equal 'tim', bm.owner
    assert_nil bm.url
  end

  def test_initialize__without_url
    bm = bmark 'name', 'mybit', 'chetan', '/bitmarks/fakeuuid/foo'
    assert_equal 'name', bm.name
    assert_equal 'mybit', bm.value
    assert_equal 'chetan', bm.owner
    assert_equal '/bitmarks/fakeuuid/foo', bm.url
  end

end
