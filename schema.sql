create table feeds (
  feed_id serial primary key,
  title varchar,
  html_url varchar, 
  xml_url varchar not null unique,
  updated timestamp,
  created timestamp default now()
);
create table items (  /* feed items */
  item_id serial primary key,
  feed_id integer references feeds on delete cascade,
  item_href varchar unique,
  title varchar,
  author varchar,
  date timestamp,
  crawled timestamp default now(),
  featured_image_id integer, -- featured image
  summary text,
  original_content text
);
create index item_item_id_idx  on items (date);
create table images (
  image_id serial primary key,
  item_id integer references items on delete cascade,
  src varchar,
  filename varchar,  -- save under dir named after the feed_id
  inserted_at timestamp default now(),
  width integer,
  height integer
);

alter table items add constraint items_featured_images_constraint foreign key (featured_image_id) references images (image_id);

create view feed_items as
  select 
    items.item_id,
    items.title, 
    items.date,
    items.item_href,
    items.summary,
    images.filename as image_file,
    items.feed_id,
    feeds.title as feed_title, 
    feeds.xml_url as feed_xml_url, 
    feeds.html_url as feed_html_url
    from items
  inner join feeds on feeds.feed_id = items.feed_id
  left outer join images on items.featured_image_id = images.image_id;

create table twitter_users (
  twitter_user_id bigint primary key,
  name varchar,
  screen_name varchar unique,
  location varchar,
  description varchar,
  profile_image_url varchar,
  url varchar,
  followers_count integer,
  friends_count integer,
  geo_enabled boolean,
  created timestamp default now()
);
create table tweets (
  tweet_id bigint primary key,
  twitter_user_id bigint references twitter_users,
  created_at timestamp with time zone,
  text varchar,
  retweet_count integer default 0,
  crawled timestamp default now()
);

