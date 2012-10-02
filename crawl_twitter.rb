require 'twitter'
require 'sequel'
require 'yaml'
require 'pp'

config = YAML::load_file('config.yml')
DB = Sequel.connect config['database']

twitter_config = config['twitter']


Twitter.configure do |c|
  c.consumer_key = twitter_config['consumer_key']
  c.consumer_secret = twitter_config['consumer_secret']
  c.oauth_token = twitter_config['access_token']
  c.oauth_token_secret = twitter_config['access_token_secret']
end

twitter_config['lists'].each do |list|

  owner = list['owner']
  slug = list['slug']

  # api = "https://api.twitter.com/1/lists/statuses.xml?owner_screen_name=#{owner}&slug=#{slug}"

  TWITTER_USER_FIELDS = %w(twitter_user_id name screen_name description location followers_count profile_image_url).map &:to_sym
  TWEET_FIELDS = %w(text retweet_count created_at).map &:to_sym

  Twitter.list_timeline(owner, slug).each {|tweet|

    u = tweet[:user].attrs
    u[:twitter_user_id] = u.delete(:id)
    params = u.select {|k,v| TWITTER_USER_FIELDS.member?(k)}

    # Create user to associate with tweets.
    # Later we can do dashboard analytics on users.

    if DB[:twitter_users].first(twitter_user_id:params[:twitter_user_id])
      DB[:twitter_users].filter(twitter_user_id:params[:twitter_user_id]).update params
      puts "Updating user: #{params[:screen_name]}"
    else
      puts "Inserting #{params.inspect}"
      DB[:twitter_users].insert params
      puts "Inserting user: #{params[:screen_name]}"
    end

    # Create tweets

    x = tweet.attrs.select{|k,v| TWEET_FIELDS.include?(k)}
    x[:tweet_id] = tweet.id
    x[:twitter_user_id] = u[:twitter_user_id]
    x[:created_at] = Time.parse(x[:created_at]).localtime
    unless  DB[:tweets].first(tweet_id:x[:tweet_id])
      # Create tweet
      DB[:tweets].insert(x)
      puts "Inserting tweet: #{x['text']}"
    end
  }
end
