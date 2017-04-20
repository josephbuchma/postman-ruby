require 'json'
require 'net/http'
require 'rest-client'
require 'delegate'

module Postman
  class URL
    def initialize(url)
      # @raw
      # @auth
      # @host
      # @path
      # @query
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

    def set_var(vars)
      vars.each { |k, v| @variable[k] = v }
    end

    def reset_var(vars)
      @variable = vars
    end

    def to_s
      interpolate
    end

    private

    def interpolate
      url = @raw
      vars = @raw.scan(/:([A-Za-z\-_]+)(?:\/|$)/).flatten
      vars.each do |v|
        url = url.gsub(':'+v, @variable[v])
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
      @method = @method.downcase.to_sym
      @url = URL.new(@url)
      @env = @environment
      if @header.nil?
        @header = {}
      else
        header = {}
        @header.each do |h|
          header[h['key']] = apply_env(h['value'])
        end
        @header = header
      end
    end

    def set_env(env)
      env.each { |k, v| @env[k] = v }
    end

    def reset_env(env)
      @env = env.clone
    end

    def execute
      if @method == :get
        new_request(:get).execute
      else
        params = {}

        unless @body.nil? && @body.empty?
          if @body['mode'] == 'raw'
            params[:payload] = @body['raw']
          elsif @body['mode'] == 'formdata'
            f = {}
            @body['formdata'].each do |d|
              if d['enabled']
                if d['type'] == 'file'
                  params[:multipart] = true
                end
                f[d['key']] = d['value'] || ""
              end
            end
            params[:payload] = f
          end
        end
        new_request(:post, params).execute
      end
    end

    private

    def apply_env(str)
      if !@env.nil?
        vars = str.scan(/\{{2}[A-Za-z_\-.]+\}{2}/)
        vars.each do |v|
          val = @env[v[2..-3]]
          raise "Request env var is missing: #{v}" if val.nil?
          str = str.gsub(v, val)
        end
      end
      str
    end

    class RequestDecorator < SimpleDelegator
      def execute
        __getobj__.execute {|response, request, result| response }
      end
    end


    def new_request(method, params={})
      params[:method] = method
      params[:url] = apply_env(@url.to_s)
      params[:headers] = @header
      r = RestClient::Request.new(params)
      RequestDecorator.new(r)
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
            if k.to_s == 'url' && itk.class == Hash
              itk = itk['raw']
            end
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

