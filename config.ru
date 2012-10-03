$:.unshift 'lib'
require './webapp.rb'
run Sinatra::Application
