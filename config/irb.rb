#!/usr/bin/ruby
# encoding: utf-8

load( File.join( File.dirname( __FILE__ ), 'antlr3.rb' ) )

require 'irb/completion'

if $project.booted?
  $project.load_environment
else
  warn( "the project environment has not been set up" )
end

