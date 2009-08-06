require 'test/unit'
require 'test/integration/webdavtestsetup'

class WebDavLimeBitsTagsTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end

  def test_tags_bind_collection
    # try creating a collection in '/tags'
    new_coll '/tags/bind_coll'
    
    # try creating a non-collection resource in '/tags'
    response = @request.put('/tags/file', StringIO.new("test_file"))
    assert_equal '403', response.status
  end

  def test_tags_unbind
    new_coll '/tags/unbind_coll'

    response = @request.delete('/tags/unbind_coll')
    assert_equal '403', response.status
  end

  def test_create_tag
    new_coll '/tags/tag_coll'
    new_coll '/tags/tag_coll/5432'

    tagp_key = RubyDav::PropKey.get('http://limebits.com/ns/1.0/', 'tag')
    response = @request.proppatch('/tags/tag_coll/5432', { tagp_key => 'yellow' })
    assert_equal '207', response.status
    assert_equal '200', response[tagp_key].status
  end

  def test_tag_owner
    new_coll '/tags/tag_owner'

    response = @request.propfind('/tags/tag_owner', 0, :owner)
    assert_equal '207', response.status
    assert_match /\/users\/limestone/, response[:owner].value
  end
end
