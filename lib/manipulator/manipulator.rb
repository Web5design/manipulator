unless defined? Magick
  begin
    require 'rmagick'
  rescue LoadError
    require 'RMagick'
  rescue LoadError
    puts "WARNING: Failed to require rmagick, image processing may fail!"
  end 
end

class Manipulator
  attr_accessor :temp_file_path
  attr_accessor :bucket

  def download bucket, key
    AWS::S3::Base.establish_connection!(:access_key_id => AWSCredentials.access_key, :secret_access_key => AWSCredentials.secret_access_key)
    @temp_file_path = File.join(Dir.tmpdir, key.gsub('/', '-'))
    File.open(temp_file_path, 'w+') do |f|
      f.puts AWS::S3::S3Object.value(key,bucket)
    end
  end

  def upload bucket, key
    AWS::S3::S3Object.store(key, File.open(temp_file_path, 'r'), bucket, :access => :public_read)
  end

  def manipulate(bucket, key, &block)
    download(bucket, key)
    begin
      image = ::Magick::Image.read(temp_file_path).first
      new_image = yield(image)
      new_image.write(temp_file_path)
      upload(bucket, key)
    ensure
      cleanup
    end
  end

  def cleanup
    File.delete temp_file_path
  end
  
end