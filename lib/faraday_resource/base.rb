require 'faraday'

# 这个是一个给proc绑定一个object的方法
class Proc
    def call_with_obj(obj, *args)
        m = nil
        p = self
        Object.class_eval do
            define_method :a_temp_method_name, &p
            m = instance_method :a_temp_method_name; remove_method :a_temp_method_name
        end
        m.bind(obj).call(*args)
    end
end

module FaradayResource
  module Base
    def self.included(base)
      base.extend(ClassMethods)
      # 添加一个attributes的proxy
      base.class_eval do
        def method_missing(name, *args)
          # 可以代理到attributes的取值
          if self.attributes.keys.include? name
            return self.attributes[name]
          elsif self.attributes.keys.include? name.to_s
            return self.attributes[name.to_s]
          end
          # 可以代理到attributes的赋值
          result = /^(.+)=$/.match(name.to_s)
          if result && result[1] && self.attributes[result[1]]
            # 如果第一次修改旧的记录那么就记录老的数据
            self.stale_attributes[result[1]] = self.attributes[result[1]] unless self.stale_attributes[result[1]]
            return self.attributes[result[1]] = args[0]
          elsif result && result[1] && self.attributes[:"#{result[1]}"]
            # 如果第一次修改旧的记录那么就记录老的数据
            self.stale_attributes[:"#{result[1]}"] = self.attributes[:"#{result[1]}"] unless self.stale_attributes[:"#{result[1]}"]
            return self.attributes[:"#{result[1]}"] = args[0]
          end
          # 否则不处理
          super
        end
      end
      # 设置一个attributes来存返回的数据
      base.class_eval do
        # 存储 attributes 和 旧的 attribtues
        attr_accessor :attributes, :stale_attributes

        # 初始化
        def initialize attrs={}
          @attributes = attrs
          @stale_attributes = {}
        end

        # 判断是否有修改
        def stale?
          self.stale_attributes.length > 0
        end
      end

      class << base
        attr_reader :url, :content_type, :parse, :array_parse

        # 这个是base的eigenclass
        eigenclass = self

        define_method :eigenclass do
          eigenclass
        end

        class << eigenclass
          # self 为base的eigenclass的eigenclass
          def post name, method_settings={}
            # self 为base的eigenclass
            inner_create_method name, :post, method_settings
          end

          def get name, method_settings={}
            inner_create_method name, :get, method_settings
          end

          def put name, method_settings={}
            inner_create_method name, :put, method_settings
          end

          def delete name, method_settings={}
            inner_create_method name, :delete, method_settings
          end

          private
          def inner_create_method name, method, method_settings
            # 定义一个方法
            define_method name do |settings={}|
              # self 为 base
              dom_url = self.url || FaradayResource.config.url
              re_url = settings['url'] || settings[:url] || method_settings['url'] || method_settings[:url]
              params = (method_settings['params'] || method_settings[:params] || {}).merge(settings['params'] || settings[:params] || {})
              if !re_url
                raise 'no relative path for the method'
              end
              if !dom_url
                raise 'no domain path for the method'
              end
              # 处理url的函数
              re_url = self.method(:parse_url).call re_url, params
              # 组建一个faraday 的 conn
              conn = Faraday.new(dom_url) do |faraday|
                faraday.adapter  Faraday.default_adapter
              end
              # 构建一个 发出一个post
              response = conn.send method do |req|
                req.url re_url
                req.headers['Content-Type'] = settings['Content-Type'] || method_settings['Content-Type'] || self.content_type || FaradayResource.config.content_type
                req.params = params
              end

              results = []
              # 判断是否解析成array
              is_array = method_settings['is_array'] || method_settings[:is_array] || settings['is_array'] || settings[:is_array]
              # 这个解析成array的items
              if response.status == 200
                if method == :get && is_array
                  parse = JSON.method(:parse)
                  parse = self.array_parse if self.array_parse
                  results = parse.call(response.body).map do |item|
                    self.new(item)
                  end
                end
              end
              # 如果要是有 is_array => true 返回 response, results
              if is_array
                return response, results
              # 否则只返回 response
              else
                return response
              end
            end
          end
        end

        # post macro 
        def post name, method_settings={}, &method_block
          method_block ||= lambda{|params, instance|}
          inner_create_method name, :post, method_settings, method_block
        end

        # get macro
        def get name, method_settings={}, &method_block
          method_block ||= lambda{|params, instance|}
          inner_create_method name, :get, method_settings, method_block
        end

        # put macro
        def put name, method_settings={}, &method_block
          method_block ||= lambda{|params, instance|}
          inner_create_method name, :put, method_settings, method_block
        end

        # delete macro
        def delete name, method_settings={}, &method_block
          method_block ||= lambda{|params, instance|}
          inner_create_method name, :delete, method_settings, method_block
        end

        # array method 返回的是array[resource]
        def collection &block
          # self 是 base
          block.call_with_obj(self.eigenclass)
        end

        private 
        def inner_create_method name, method, method_settings, method_block
          # 定义一个方法
          define_method name do |settings={}|
            dom_url = self.class.url || FaradayResource.config.url
            re_url = settings['url'] || settings[:url] || method_settings['url'] || method_settings[:url]
            params = (method_settings['params'] || method_settings[:params] || {}).merge(settings['params'] || settings[:params] || {})
            if !re_url
              raise 'no relative path for the method'
            end
            if !dom_url
              raise 'no domain path for the method'
            end
            # 处理url的函数
            re_url = self.class.method(:parse_url).call re_url, params
            # 组建一个faraday 的 conn
            conn = Faraday.new(dom_url) do |faraday|
              faraday.adapter  Faraday.default_adapter
            end
            # 构建一个 发出一个post
            response = conn.send method do |req|
              req.url re_url
              req.headers['Content-Type'] = settings['Content-Type'] || method_settings['Content-Type'] || self.class.content_type || FaradayResource.config.content_type
              params = method_block.call(params, self)
              req.params = params
            end

            if response.status == 200
              if method == :get || method == :post || method == :put
                parse = JSON.method(:parse)
                parse = self.class.parse if self.class.parse
                self.attributes = parse.call(response.body)
                self.stale_attributes = {}
              end
            end
            return response
          end
        end

        # 处理url
        def parse_url url, options
          url.gsub /:(\w+)/ do |str|
            options[:"#{$1}"] || options["#{$1}"] || ''
          end
        end

      end
    end
  end

  module ClassMethods
    # 设置url
    def set_url url
      self.instance_eval do
        @url = url
      end
    end

    # 设置content_type
    def set_content_type content_type
      self.instance_eval do
        @content_type = content_type
      end
    end

    # set parse method
    def set_parse &block
      self.instance_eval do
        @parse = block
      end
    end

    def set_array_parse &block
      self.instance_eval do
        @array_parse = block
      end
    end

  end
end