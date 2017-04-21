# Postman-Ruby

Play with [Postman's](https://www.getpostman.com/) request collections using Ruby.

## Install

```
gem install postman-ruby
```

## Usage

1. Export collection from Postman to JSON file (Collection V2)
2. Example code:

```ruby
require 'postman-ruby'

# Parse exported collection JSON
p = Postman.parse_file('exported_requests_collection.json')

# Set some environment variables if needed
p.set_env('host' => 'http://localhost:9090', 'access_token' => 'x5CACj1cmrRLtt7EgIBxblYrfcrJVbQL820QJ1kNY')

# Filter by hash
filtered = p.filter('method' => 'get', 'name'=>/.*(search|find).*/i)

# Filter with block
filtered = p.filter do |r|
  r.method == :get && r.name.include?('search') && r.url.raw.include?('foobar')
end

# Make some requests
filtered.each do |r|
  resp = r.execute # => RestClient::Response

  # ...
end

```
