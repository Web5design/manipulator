require 'mini_magick'

# Using Manipulator is as simple as creating an instance and calling manipulate.
#
# The connection to S3 is opened using credentials read from AWSCredentials.
class Manipulator
  attr_accessor :temp_file_path
  def initialize(options = {})
    MiniMagick.processor = options[:processor]
  end

  # Establishes a connection to S3
  # Pass the bucket for virtual-hosted-style urls back from amazon
  # e.g. mybucket.s3.amazonaws.com vs s3.amazonaws.com/mybucket
  # NOTE: this requires jacqui's fork of the aws-s3 gem due to a bug:
  # http://github.com/jacqui/aws-s3
  def connect_to_s3(bucket = nil)
    if bucket
      AWS::S3::Base.establish_connection!(:access_key_id => AWSCredentials.access_key, :secret_access_key => AWSCredentials.secret_access_key, :server => "#{bucket}.s3.amazonaws.com")
    else
      AWS::S3::Base.establish_connection!(:access_key_id => AWSCredentials.access_key, :secret_access_key => AWSCredentials.secret_access_key, :server => "s3.amazonaws.com")
    end
  end

  # Downloads the specified key from the S3 bucket to a local temp file
  def download(bucket, key)
    connect_to_s3
    @temp_file_path = File.join(Dir.tmpdir, key.gsub('/', '-'))
    File.open(temp_file_path, 'w+') do |f|
      f.puts AWS::S3::S3Object.value(key,bucket)
    end
  end

  # Pushes contents of temp file back to specified bucket, key on S3
  # Returns the url for the file
  def upload(bucket, key)
    connect_to_s3(bucket)
    AWS::S3::S3Object.store(key, File.open(temp_file_path, 'r'), bucket, :access => :public_read)
    AWS::S3::S3Object.url_for(key, bucket, :authenticated => false)
  end

  # Specify a S3 key to manipulate (and its bucket).
  #
  # Block yields a MiniMagick::Image image instance with access to MiniMagick's methods
  # Note that you don't have to chain methods to return the image with all manipulations using MiniMagick:
  # For example, use
  #  m.manipulate('my-bucket', 'my-key') do |img|
  #    img.rotate(90)
  #    img.resize(100x100)
  #  end
  # Want to do something that MiniMagick doesn't directly support, like
  # removing all profiles from an image with GraphicsMagick (aka ImageMagick's strip method)
  # m.manipulate('my-bucket', 'my-key' do |img|
  #   `gm mogrify +profile '*' #{manipulator.temp_file_path}`
  # end
  def manipulate(options, &block)

    download(options[:bucket], options[:key])
    begin
      image = MiniMagick::Image.open(temp_file_path)
      image.combine_options do |i|
        yield(i)
      end
      target_key = options[:target_key] || options[:key]
      # todo: save this file to a new name instead of overwriting it.
      target_local_path = options[:target_key] || options[:key]
      image.write(temp_file_path)

      unless options[:keep_local]
        upload(options[:bucket], target_key)
      end
    rescue Exception => e
      puts e.message
      puts e.backtrace
    ensure
      cleanup
    end
  end

  # Removes the temp file
  def cleanup
    File.delete(temp_file_path)
  end

end
