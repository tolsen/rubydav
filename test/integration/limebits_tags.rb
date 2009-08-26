require 'test/unit'
require 'test/integration/webdavtestsetup'

class WebDavLimeBitsbitmarksTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end

  def test_bitmarks_bind_collection
    # try creating a collection in '/bitmarks'
    new_coll '/bitmarks/bind_coll'
    
    # try creating a non-collection resource in '/bitmarks'
    response = @request.put('/bitmarks/file', StringIO.new("test_file"))
    assert_equal '403', response.status
  end

  def test_bitmarks_unbind
    new_coll '/bitmarks/unbind_coll'

    response = @request.delete('/bitmarks/unbind_coll')
    assert_equal '403', response.status
  end

  def test_create_tag
    new_coll '/bitmarks/tag_coll'
    new_coll '/bitmarks/tag_coll/5432'

    tagp_key = RubyDav::PropKey.get('http://limebits.com/ns/1.0/', 'tag')
    response = @request.proppatch('/bitmarks/tag_coll/5432', { tagp_key => 'yellow' })
    assert_equal '207', response.status
    assert_equal '200', response[tagp_key].status
  end

  def test_tag_owner
    new_coll '/bitmarks/tag_owner'

    response = @request.propfind('/bitmarks/tag_owner', 0, :owner)
    assert_equal '207', response.status
    assert_match /\/users\/limestone/, response[:owner].value
  end
end
