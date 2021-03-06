require File.expand_path("helper", File.dirname(__FILE__))

class ReadMixinTest < ActiveSupport::TestCase

  context "find by sql with kasket" do
    setup do
      @post_database_result = { 'id' => 1, 'title' => 'Hello' }
      @post_records = [Post.send(:instantiate, @post_database_result)]
      Post.stubs(:find_by_sql_without_kasket).returns(@post_records)

      @comment_database_result = [{ 'id' => 1, 'body' => 'Hello' }, { 'id' => 2, 'body' => 'World' }]
      @comment_records = @comment_database_result.map {|r| Comment.send(:instantiate, r)}
      Comment.stubs(:find_by_sql_without_kasket).returns(@comment_records)
    end

    should "handle unsupported sql" do
      Kasket.cache.expects(:read).never
      Kasket.cache.expects(:write).never
      assert_equal @post_records, Post.find_by_sql_with_kasket('select unsupported sql statement')
    end

    should "read results" do
      Kasket.cache.write("kasket-#{Kasket::Version::STRING}/posts/version=3558/id=1", @post_database_result)
      assert_equal @post_records, Post.find_by_sql('SELECT * FROM `posts` WHERE (id = 1)')
    end

    should "store results in kasket" do
      Post.find_by_sql('SELECT * FROM `posts` WHERE (id = 1)')

      assert_equal @post_database_result, Kasket.cache.read("kasket-#{Kasket::Version::STRING}/posts/version=3558/id=1")
    end

    should "store multiple records in cache" do
      Comment.find_by_sql('SELECT * FROM `comments` WHERE (post_id = 1)')
      stored_value = Kasket.cache.read("kasket-#{Kasket::Version::STRING}/comments/version=3476/post_id=1")
      assert_equal(["kasket-#{Kasket::Version::STRING}/comments/version=3476/id=1", "kasket-#{Kasket::Version::STRING}/comments/version=3476/id=2"], stored_value)
      assert_equal(@comment_database_result, stored_value.map {|key| Kasket.cache.read(key)})

      Comment.expects(:find_by_sql_without_kasket).never
      assert_equal(@comment_records, Comment.find_by_sql('SELECT * FROM `comments` WHERE (post_id = 1)'))
    end

    context "modifying results" do
      setup do
        Kasket.cache.write("kasket-#{Kasket::Version::STRING}/posts/version=3558/id=1", @post_database_result)
        @record = Post.find_by_sql('SELECT * FROM `posts` WHERE (id = 1)').first
        @record.instance_variable_get(:@attributes)['id'] = 3
      end

      should "not impact other queries" do
        same_record = Post.find_by_sql('SELECT * FROM `posts` WHERE (id = 1)').first

        assert_not_equal @record, same_record
      end

    end

  end

end
