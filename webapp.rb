require 'sinatra'
require 'sequel'
require 'json'
require 'logger'
require 'nokogiri'
require 'yaml'
require 'uri'
require 'open-uri'

config = YAML::load_file('config.yml')
DB = Sequel.connect config['database']

class Array
  def uniq_by
    hash, array = {}, []
    each { |i| hash[yield(i)] ||= (array << i) }
    array
  end
end

set :static, true
set :root, File.dirname(__FILE__)

helpers do

  def page_config
    config['page']
  end

  def set_image(p)
    if p[:image_file]  
      image_path = "/feed-images/#{p[:item_id]}/#{p[:image_file]}"
      p[:image_tag] = %Q[<a href="#{p[:item_href]}"><img class="feed-item-image" src="#{image_path}"/></a>] 
    elsif p[:podcast_image]
      p[:image_tag] = %Q[<a href="#{p[:item_href]}"><img class="podcast-image" src="#{p[:podcast_image]}"/></a>] 
    elsif p[:enclosure] && p[:enclosure] =~ /(jpg|gif|png|jpeg)$/i
      p[:image_tag] = %Q[<a href="#{p[:item_href]}"><img class="feed-item-image" src="#{p[:enclosure]}"/></a>] 
    else
      p[:image_tag] = ''
    end
    if p[:image_tag] =~ /placeholder/ 
      p[:image_tag] = ''
    end
  end

  def prep_feed_item(p)
    p[:date_string] = p[:date].strftime("%b %d %I:%M %p")
    set_image p
    p[:audio_tag] = ''
    if p[:enclosure] && (p[:enclosure] =~ /mp3$/)
      #p[:audio_tag] = %Q|<audio src="#{p[:enclosure]}" controls> #{p[:enclosure]}</audio>|
      filename = p[:enclosure][/[^\/]+\/?$/,0]
      p[:audio_tag] = %Q|
      <audio src="#{p[:enclosure]}" controls preload="none"></audio>
      <a href="#{p[:enclosure]}">download</a>
      |
    end
    p
  end

  def prep_tweet t
    tweet_href = "<a href='http://twitter.com/#{t[:screen_name]}/status/#{t[:tweet_id]}'>#{t[:created_at].strftime("%b %d %I:%M %p")}</a>"
    t[:screen_name].gsub!(/.*/, '<a href="http://twitter.com/\0">\0</a>')
    new = t[:text].gsub(/http:[\w\-_\.\/]+/, '<a href="\0">\0</a>')
    new = new.gsub(/@(\w+)/, '<a href="http://twitter.com/\1">@\1</a>')
    t[:date_string] = tweet_href
    t[:text] = new 
    t
  end

  def tweets(params={})
    @tweets = DB["select tweets.*, twitter_users.* from tweets inner join twitter_users using (twitter_user_id)"].
      order(:created_at.desc).limit(200)
    if params[:from_time]
      @tweets = @tweets.filter("created_at > ?", URI.unescape(params[:from_time]))
    end
    @tweets.to_a
  end

  def feed_items
    items = DB[:feed_items].order(:date.desc).limit(100)
    if params[:from_time]
      items = items.filter("date > ?", URI.unescape(params[:from_time]))
    end
    items.to_a
  end
end

get '/feed_items' do 
  items = DB[:feed_items].order(:date.desc).limit(100)
  if params[:from_time]
    items = items.filter("date > ?", URI.unescape(params[:from_time]))
  end
  items.to_a.to_json
end

get '/' do
  @tweets = tweets.map {|t| prep_tweet t}
  @feed_items = feed_items.map {|t| prep_feed_item t}
  erb :home
end

get '/tweets' do 
  resp = tweets(from_time: params[:from_time]).map {|x| prep_tweet x}.to_json
end

get '/feed_items' do 
  resp = feed_items(from_time: params[:from_time]).map {|x| prep_feed_item x}.to_json
end

