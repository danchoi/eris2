# eris2

A DIY planet + twitter aggregator.

## Prerequisists

* Ruby 1.9
* tidy 
* imagemagick
* PostgreSQL

## Install

    https://github.com/danchoi/eris2
    bundle install
    createdb eris
    psql -d eris -f schema.sql

## Configure

Copy `config.sample.yml` to config.yml and fill in the correct values. 

## Crawl Twitter and Feeds

To fill the database with tweets and feed items, run these scripts:

    ./crawl-tweets.sh
    ./crawl-feeds.sh

## Start the webapp in development mode

    rackup

Visit `http://localhost:9292`.

For production deployments, follow specific Rack app instructions
for Passenger, Unicorn, etc.

## Credits

Created by Daniel Choi and Malcolm Cowell, of Betahouse. 

