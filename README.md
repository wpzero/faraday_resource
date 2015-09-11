# FaradayResource

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/faraday_resource`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'faraday_resource'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install faraday_resource

## Usage



such as:		
 
```
	
	class User
	  include FaradayResource::Base
	
	  set_url 'http://localhost:5100'
	
	  set_content_type 'application/json'
	
	  get :load, 'url' => '/users/:id', 'params' => {:test => 'dfdjfk', :id => 1}
	
	  collection do
	    get :get_list, 'url' => '/users', 'is_array' => true
	  end
	end
```
	
now you can use User class such as:



```
	user = User.new
	response = user.load #=> fetch data
	user.name #=> get name
	response.status #=> status code faraday response	
```

	

if is_array is true return response and array[user] or only response

	
	
	
```
	response, users = User.get_list #=> only when is_array is true
	response.status #=> status code faraday response
	users.class #=> Array, array[user]
	
	response = User.get_list #=> when is_array is false 
```
	
overwrite url params

	
```
	User.get_list({
		:url => '/other_users',
		:params => {
			:q => 'wp'
		}
	})
	
	#now faraday use '/other_users' and params will merge this params
```

	
you can set custom parse function for instance_methods (default JSON.parse)

	

```

	class User
		set_parse do |body|
			JSON.parse(body)['entity']
		end
	end
```

	
you can set custom array_parse function for is_array is true (default JSON.parse)

		
		
```
	class User
		set_array_parse do |body|
			JSON.parse(body)['entities']
		end
	end
```

	
you can set global setting (will be overwitten by class set_url..)

	
```
	FaradayResource.configure do |settings|
	  settings.url = 'http://localhost:5100'
	  settings.content_type = 'application/json'
	end
	
```
	
url params xxx will replaced by params[:xxx] or params[xxx]		
	
```			
	class User
	
		get :load, 'url' => '/users/:id', 'params' => {:test => 'dfdjfk', :id => 1} do |params, instance|
		    params['test'] = instance.name
		    params
		end
	end
```
	
	
get/post/put/delete methods (not in collection) can accept block (params, instance then return params)

	
```			
	class User
	
		put :update, 'url' => '/users/:id', 'params' => {} do |params, instance|
		    params['user'] = {
		    	:name => instance.name,
		    	:age => instance.age
		    }
		    params
		end
	end
	
	u = User.new({id: 2})
	u.load
	u.name = 'zkf'
	u.update
```
	
can assign value for attributes, check stale?

```
	u = User.new({id: 2})
	u.load
	u.name #=> 'wp'
	u.name = 'zkf'
	u.name #=> 'zkf'
	u.stale? #=> true
	u.stale_attributes #=> {'name': 'wp'}
```	



##other

I think this gem will help communicating between app servers (soa)

我水平有限(low)，如果有什么好的想法(good tips)，可以联系我（concat me） qq:524162910  email:wpcreep@gmail.com
	


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/faraday_resource/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
