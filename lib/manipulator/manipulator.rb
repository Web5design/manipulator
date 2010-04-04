# Tries to avoid case-sensitivity issues when requiring RMagick.
# Borrowed from jnicklas' carrierwave.
unless defined? Magick
  begin
    require 'rmagick'
  rescue LoadError
    require 'RMagick'
  rescue LoadError
    puts "WARNING: Failed to require rmagick, image processing may fail!"
  end 
end


# Using Manipulator is as simple as creating an instance and calling manipulate.
#
# The connection to S3 is opened using credentials read from AWSCredentials.
class Manipulator
  
  # Path to the local temp file used during manipulation
  attr_accessor :temp_file_path

  # Downloads the specified bucket, key from S3 to a local temp file
  # and sets temp_file_path
  def download(bucket, key)
    AWS::S3::Base.establish_connection!(:access_key_id => AWSCredentials.access_key, :secret_access_key => AWSCredentials.secret_access_key)
    @temp_file_path = File.join(Dir.tmpdir, key.gsub('/', '-'))
    puts "temp_file_path: #{temp_file_path}"
    File.open(temp_file_path, 'w+') do |f|
      f.puts AWS::S3::S3Object.value(key,bucket)
    end
  end
  
  # Pushes contents of temp file back to specified bucket, key on S3
  def upload(bucket, key)
    AWS::S3::S3Object.store(key, File.open(temp_file_path, 'r'), bucket, :access => :public_read)
  end

  # Specify a S3 key to manipulate (and its bucket).
  #
  # Block yields a Magick::Image image instance with access to the usual RMagick methods.
  # Note that RMagick methods should be chained so that block returns image with all manipulations.
  # For example, use
  #  m.manipulate('my-bucket', 'my-key') do |img|
  #    img.rotate(90).sepia_tone
  #  end
  # rather than
  #  img.rotate(90)
  #  img.sepia_tone
  # This last case will only <tt>sepia_tone</tt> the image.
  def manipulate(options, &block)
    download(options[:bucket], options[:key])
    begin
      image = ::Magick::Image.read(temp_file_path).first
      new_image = yield(image)
      new_image.write(temp_file_path)
      upload(options[:bucket], options[:key]) unless options[:keep_local]
    ensure
      cleanup
    end
  end

  # Removes the temp file
  def cleanup
    File.delete(temp_file_path)
  end
  
end
