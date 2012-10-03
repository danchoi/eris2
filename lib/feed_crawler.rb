# fetches and processes feeds
require 'feed_yamlizer'
require 'feed_item'
require 'nokogiri'
require 'sequel'

config = YAML::load_file('config.yml')
DB = Sequel.connect config['database']
feeds = config['feeds']


feeds.each do |f|
  title = f['title']
  xml_url = f['xml_url']
  html_url = f['html_url']
  
  if (feed = DB[:feeds].first(xml_url:xml_url))
    puts "Updating feed: #{title} #{xml_url}"
    DB[:feeds].filter(feed_id:feed[:feed_id]).update(updated:Time.now)
  else
    feed_id = DB[:feeds].insert(f.merge(created: Time.now))
    feed = DB[:feeds].first(xml_url:xml_url)
  end

  cmd = "curl -Ls -A 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.0.3) Gecko/2008092416 Firefox/3.0.3'  '#{xml_url}' "
  cmd += " | feed2yaml "
  puts cmd

  feed_yml = YAML::load `#{cmd}`
  feed_info = feed_yml[:meta]
  items = feed_yml[:items]
  feed_params = { html_url:feed_info[:link], title:feed_info[:title].strip, xml_url:xml_url }
  if (feed = DB[:feeds].first(xml_url:feed_params[:xml_url]))
    DB[:feeds].filter(xml_url:feed_params[:xml_url]).update(feed_params)
    feed_id = feed[:feed_id]
    print '.'
  else
    puts "Adding feed #{feed_info.inspect}"
    feed_id = DB[:feeds].insert feed_params
  end
  items.each {|i| 
    unless i[:pub_date]
      puts "No pub date! Rejecting"
      next
    end
    item_params = { 
      feed_id: feed_id,
      item_href: i[:link],
      title: i[:title],
      author: i[:author],
      date: i[:pub_date],
      original_content: i[:content][:html]
    }
    if DB[:items].first item_href: item_params[:item_href]
      $stderr.print '.'
    else
      puts "Inserting item => #{item_params[:title]} (feed #{feed_id})"
      item = FeedItem.new(DB[:items].insert(item_params))
      item.create_summary_and_images 
    end
  }
end


