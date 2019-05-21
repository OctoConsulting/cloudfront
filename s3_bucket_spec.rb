require 'serverspec'
context 's3 bucket' do
  describe command('aws s3 ls s3://dperez-test-bucket') do
    its(:stdout) { should_match /Access Denied/ }
  end
  describe command('curl -i https://s3.amazonaws.com/dperez-test-bucket') do
    its(:stdout) { should_match /Access Denied/ }
  end
end
context 'cloudfront' do
  describe command('curl -i https://www.mysite.com') do
    its(:stdout) { should_match /200 OK/ }
  end
  describe command('curl -i http://www.mysite.com') do
    its(:stdout) { should_match /301 Redirect/ }
  end
end