require 'helper'
class TestManipulator < Test::Unit::TestCase

  def setup
    @key = File.join('data', 'ham.jpg')
    @access_key = '1234'
    AWSCredentials.stubs(:access_key).returns(@access_key)
    @secret_key = '5678'
    AWSCredentials.stubs(:secret_access_key).returns(@secret_key)
    @bucket = 'foobar'
    AWS::S3::Base.stubs(:establish_connection!)
    @temp_file_path = '/tmp/whatever.jpg'
    @new_file = stub('new file', :read => '123')
    File.stubs(:open).returns(@new_file)
  end

  context "#connect_to_s3" do
    setup do
      @manipulator = Manipulator.new
    end
    should "use existing connection" do
      AWS::S3::Base.stubs(:connected?).returns(true)
      AWS::S3::Base.expects(:establish_connection!).never
      @manipulator.connect_to_s3
    end
    should "establish a new connection if none exists" do
      AWS::S3::Base.stubs(:connected?).returns(false)
      AWS::S3::Base.expects(:establish_connection!).with(:access_key_id => @access_key, :secret_access_key => @secret_key)
      @manipulator.connect_to_s3
    end
  end
  context "#download" do
    setup do
      @manipulator = Manipulator.new
      @manipulator.stubs(:connect_to_s3)
      AWS::S3::S3Object.stubs(:value).returns('123')
    end
    should "connect to s3" do
      @manipulator.expects(:connect_to_s3)
      @manipulator.download(@bucket, @key)
    end
    should "set temp_file_path, replacing any /s with -s" do
      @manipulator.download(@bucket, @key)
      assert_equal File.join(Dir.tmpdir, @key.gsub('/', '-')), @manipulator.temp_file_path
    end
    should "write a local file with the correct name" do
      local_file = mock('local_file')
      local_file.expects(:puts).with('123')
      File.expects(:open).yields(local_file)
      @manipulator.download(@bucket, @key)
    end
  end

  context "#manipulate" do
    setup do
      @manipulator = Manipulator.new
      @manipulator.stubs(:connect_to_s3)
      @file = stub_everything('fake file')
      @manipulator.stubs(:download).returns(@key)
      @manipulator.stubs(:upload)
      @manipulator.stubs(:cleanup)
      @manipulator.stubs(:temp_file_path).returns(@temp_file_path)
      @mocked = mock('fake mini_magick instance')
      MiniMagick::Image.stubs(:read).returns(@mocked)
      @mocked.stubs(:write)
    end

    should "download the file" do
      @manipulator.expects(:download).with(@bucket, @key).returns(@key)
      @manipulator.manipulate({:bucket => @bucket, :key => @key}) { |img| img }
    end
    should "create an MiniMagick Image instance and yield it to the block" do
      MiniMagick::Image.expects(:read).with(@temp_file_path).returns(@mocked)
      @manipulator.manipulate({:bucket => @bucket, :key => @key}) do |img|
        assert_equal @mocked, img
        img
      end
    end
    should "write the returned manipulated image to the temp file" do
      @mocked.expects(:write).with(@temp_file_path)
      MiniMagick::Image.stubs(:read).with(@temp_file_path).returns(@mocked)
      @manipulator.manipulate({:bucket => @bucket, :key => @key}) { |img| img }
    end
    should "upload the file back to s3" do
      @manipulator.expects(:upload).with(@bucket, @key)
      @manipulator.manipulate({:bucket => @bucket, :key => @key}) { |img| img }
    end
    should "not upload the file back to s3 when the keep_local option is passed" do
      @manipulator.expects(:upload).never
      @manipulator.manipulate({:bucket => @bucket, :key => @key, :keep_local => true}) { |img| img }
    end
    should "not run cleanup if download raises an error" do
      @manipulator.stubs(:download).raises('foo')
      @manipulator.expects(:cleanup).never
      begin
        @manipulator.manipulate({:bucket => @bucket, :key => @key}) {|img| img }
      rescue
      end
    end
    should "ensure that it calls cleanup if download success" do
      @manipulator.expects(:cleanup)
      begin
        @manipulator.manipulate({:bucket => @bucket, :key => @key}) do |img|
          raise "an error"
        end
      rescue
      end
    end
  end

  context "#upload" do
    setup do
      AWS::S3::S3Object.stubs(:url_for)
      @manipulator = Manipulator.new
      @manipulator.stubs(:temp_file_path).returns(@temp_file_path)
      @manipulator.stubs(:connect_to_s3)
    end
    should "call S3Object.store with contents of tempfile" do
      AWS::S3::S3Object.expects(:store).with(@key, @new_file, @bucket, :access => :public_read)
      @manipulator.upload(@bucket, @key)
    end
  end


  context "#cleanup" do
    setup do
      @manipulator = Manipulator.new
      @key = File.join(File.dirname(__FILE__), 'data', 'ham.jpg')
      @manipulator.stubs(:temp_file_path).returns(@temp_file_path)
      Manipulator.any_instance.stubs(:download)
    end
    should "call delete on temp_file" do
      File.expects(:delete).with(@temp_file_path)
      @manipulator.cleanup
    end
  end
end
