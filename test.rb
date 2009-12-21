require 'rubygems'
require 'lib/manipulator'

AWSCredentials.config_path = '/etc/aws.staging.conf'
m = Manipulator.new
m.manipulate('fluffy-dev','uploads/submission/image/4b103d3b3fe2263d89000002/fennec_fox.jpg') do |img|
  img.rotate(90)
end
