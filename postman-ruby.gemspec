Gem::Specification.new do |s|
  s.name        = 'postman-ruby'
  s.version     = '0.1.0'
  s.date        = '2017-04-18'
  s.summary     = "Postman requests collection parser"
  s.description = "Allows to parse Postman's JSON reqeuests collection dump and make requests from ruby"
  s.authors     = ["Joseph Buchma"]
  s.email       = 'josephbuchma@gmail.com'
  s.files       = ["lib/postman-ruby.rb"]
  s.homepage    =
    'http://github.com/josephbuchma/postman-ruby'
  s.license       = 'MIT'

  s.add_runtime_dependency 'rest-client', '~> 2.0.0', '>= 2.0.0'
end
