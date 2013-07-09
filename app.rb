require 'rubygems'
require 'sinatra'
require 'sinatra/config_file'
require 'data_mapper'
require 'time'
require 'dm-migrations'
require 'oauth'
require 'oauth/consumer'
require 'json'

config_file 'config.yml'

DataMapper.setup(:default, 'sqlite:///webapps/sinatra_test/db/sinatra_test.db')

class User
    include DataMapper::Resource

    property :id,               Serial
    property :token,            Text
    property :token_secret,     Text
    property :created_at,       DateTime
    property :updated_at,       DateTime
end

DataMapper.auto_migrate!

enable :sessions

get '/' do
	erb :index
end

get '/twitter_login' do
    @consumer = OAuth::Consumer.new settings.twitter_consumer_key,
                                    settings.twitter_consumer_secret,
                                    {:site=>"https://api.twitter.com"}

    @request_token = @consumer.get_request_token :oauth_callback => "http://tweetmood.brianj.me/twitter_callback"
    session[:request_token] = @request_token
    redirect @request_token.authorize_url
end

get '/twitter_callback' do
    @request_token = session[:request_token]
    @access_token = @request_token.get_access_token :oauth_verifier => params[:oauth_verifier] 

    @token = @access_token.token
    @secret = @access_token.secret

    @user = User.first(:token => @token)

    if @user == nil
        @user = User.create(
            :token          => @token,
            :token_secret   => @secret,
            :created_at     => Time.now,
            :updated_at     => Time.now
        )
    end
    
    session[:userid] = @user.id

    redirect '/tweet_search'
end

get '/tweet_search' do
    if session[:userid] != nil
        @user = User.first(:id => session[:userid])

        if @user != nil
            erb :tweet_search
        else
            redirect '/'
        end
    else
        redirect '/'
    end
end

get '/search_tweets' do
    @search = params['search']

    if session[:userid] != nil
        @user = User.first(:id => session[:userid])

        if @user != nil
            @consumer = OAuth::Consumer.new settings.twitter_consumer_key,
                                            settings.twitter_consumer_secret,
                                            {:site=>"https://api.twitter.com"}

            @access_token = OAuth::AccessToken.new @consumer,
                                                   @user.token,
                                                   @user.token_secret
            
            @tweets = @access_token.get('/1.1/search/tweets.json?q=' + @search + '&lang=en')
            
            content_type :json
            @tweets.body

        else
            status 500
        end
    else
        status 500
    end
end

get '/about' do
    erb :about
end

get '/contact' do
    erb :contact
end

