require 'twitter'
require 'sequel'
require 'yaml'
require 'pp'

TWITTER_USER_FIELDS = %w(twitter_user_id name screen_name description location followers_count profile_image_url).map &:to_sym
TWEET_FIELDS = %w(text retweet_count created_at).map &:to_sym

config = YAML::load_file('config.yml')
DB = Sequel.connect config['database']
twitter_config = config['twitter']

Twitter.configure do |c|
  c.consumer_key = twitter_config['consumer_key']
  c.consumer_secret = twitter_config['consumer_secret']
  c.oauth_token = twitter_config['access_token']
  c.oauth_token_secret = twitter_config['access_token_secret']
end

((twitter_config['searches'] || []) + (twitter_config['lists'] || [])).each do |search_or_list|

  results = if (q = search_or_list['query'])
    puts "-- Updating twitter search query: #{q}"
    Twitter.search(q).statuses
  else
    owner = search_or_list['owner']
    slug = search_or_list['slug']
    puts "-- Updating twitter list: #{owner}#:#{slug}"
    Twitter.list_timeline(owner, slug)
  end

  results.each {|tweet|
    u = tweet[:user].attrs
    u[:twitter_user_id] = u.delete(:id)
    params = u.select {|k,v| TWITTER_USER_FIELDS.member?(k)}

    # Create user to associate with tweets.
    # Later we can do dashboard analytics on users.

    if DB[:twitter_users].first(twitter_user_id:params[:twitter_user_id])
      DB[:twitter_users].filter(twitter_user_id:params[:twitter_user_id]).update params
      #puts "Updating user: #{params[:screen_name]}"
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
    if (t =  DB[:tweets].first(tweet_id:x[:tweet_id]))
      puts "Tweet already saved. #{t[:tweet_id]}: #{t[:text]}"
      DB[:tweets].filter(tweet_id:x[:tweet_id]).update(x)
    else 
      # Create tweet
      puts "Saving tweet #{t[:tweet_id]}: #{t[:text]}"
      DB[:tweets].insert(x)
      puts "Inserting tweet: #{x['text']}"
    end
  }
end
