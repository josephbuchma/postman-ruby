require 'json'
require 'net/http'

module Postman
  class URL
    def initialize(url)
      # @raw
      # @auth
      # @host
      # @path
      # @variable
      if url.class == String
        url = {
          'raw' => url,
          'auth' => {},
          'host' => [],
          'path' => [],
          'variable' => {},
        }
      end
      @raw = url
      url.each do |k,v|
        instance_variable_set("@#{k}", v)
        self.class.send(:attr_reader, k.to_sym)
      end

      if !@variable.nil? && !@variable.empty?
        var = {}
        @variable.each do |v|
          var[v['id']] = v['value']
        end
        @variable = var
      end
    end

    def to_s
      interpolate
    end

    private

    def interpolate
      url = @raw
      vars = @raw.scan(/:[A-Za-z\-_]+\//)
      vars.each do |v|
        url = url.gsub(v, @variable[v[1..-1]])
      end
      url
    end
  end

  class Request
    def initialize(params)
      # @name
      # @description
      # @method
      # @url
      # @header
      # @body
      # @environment
      params.each do |k,v|
        instance_variable_set("@#{k}", v)
        self.class.send(:attr_reader, k.to_sym)
      end
      @url = URL.new(@url)
      @env = @environment
    end

    def set_env(env)
      env.each { |k, v| @env[k] = v }
    end

    def reset_env(env)
      @env = env.clone
    end

    def call
      send @method.downcase.to_sym
    end

    private

    def apply_env(str)
      vars = str.scan(/\{{2}[A-Za-z_\-.]+\}{2}/)
      vars.each do |v|
        val = @env[v[2..-3]]
        raise "Request env var is missing: #{v}" if val.nil?
        str = str.gsub(v, val)
      end
      str
    end

    def get
      uri = URI(apply_env(@url.to_s))
      req = Net::HTTP::Get.new(uri)
      if @header.class == Array
        @header.each do |h|
          req[h['key']] = apply_env(h['value'])
        end
      end
      Net::HTTP.start(uri.host, uri.port) do |http|
        return http.request req # Net::HTTPResponse object
      end
    end
  end

  FILTER_KEYS=%w(name url method description)

  class Collection
    def initialize(hash={})
      @parsed = hash
      @parsed['item'] = [] if @parsed['item'].nil?
      @env = {}
    end

    def set_env(env)
      env.each do |k, v|
        @env[k] = v
      end
    end

    def reset_env(env={})
      @env = env.clone
    end

    def filter(flt_hash={}, &block)
      flt_hash.each do |k, v|
        if v.nil?
          raise ArgumentError.new("filter value must be string")
        end
        if !FILTER_KEYS.include?(k.to_s)
          raise ArgumentError.new("invalid filter key \"#{k}\", allowed keys: [#{FILTER_KEYS.join(', ')}]")
        end
      end
      filter_collection(@parsed, flt_hash, &block)
    end

    def to_a
      filter
    end

    private

    def make_child_request(params)
      r = Request.new(params)
      r.reset_env(@env)
      r
    end

    def filter_collection(collection, flt_hash={}, &block)
      ret = []
      collection['item'].each do |item|
        if is_collection(item)
          ret += filter_collection(item, flt_hash, &block)
        elsif is_request(item)
          req = item['request']
          req['name'] = item['name']
          req['response'] = item['response']
          if block_given? || flt_hash.empty?
            r = make_child_request(req)
            next if block_given? && ! yield(r)
            ret << r
            next
          end
          score = 0
          flt_hash.each do |k, v|
            itk = req[k.to_s]
            if !itk.nil?
              score+=1 if v.class == Regexp && v =~ itk || v.class == String && v.downcase == itk.downcase
            end
          end
          if score == flt_hash.size
            r = make_child_request(req)
            ret << r
          end
        end
      end
      ret
    end

    def is_collection(item)
      item['item'].class == Array
    end

    def is_request(item)
      !item['request'].nil?
    end
  end


  def self.parse(json)
    Collection.new(JSON.parse(json))
  end

  def self.parse_file(name)
    Postman.parse(File.read(name))
  end
end

