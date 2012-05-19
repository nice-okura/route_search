#! /usr/bin/ruby 
# -*- coding: utf-8 -*-
#
#= 国道抽出プログラム
#
#Authors:: Takahiro FUJITANI
#Version:: 0.1
#License:: Apache License, Version 2.0
#
#== Usage:
#
#==== シミュレーション時間の指定
# # ./schesim.rb -e 200000
#

require "net/http"
require "rubygems"
require "open-uri"
require "nokogiri"
require "pp"

#
#=Macros
#
ROOT_URL = "http://maps.google.com"
#PATH = "/maps/geo?ll=36.260331,137.439516&output=xml&key=GOOGLE_MAPS_API_KEY&hl=ja&oe=UTF8"
PATH_A = "http://maps.google.com/maps/geo?ll="
PATH_B = "&output=xml&hl=ja&oe=UTF8"
ROUTE_XPATH = "//addressline"

#
#=main
#
lat = 36.260331
lon = 137.439516
lat.step(38.0, 0.001){ |l|
  geo = "#{l},#{lon}"
  url = "#{PATH_A}#{geo}#{PATH_B}"
  doc = Nokogiri.HTML(open(url))
  puts doc.xpath(ROUTE_XPATH).text
}
