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
#=緯度経度クラス
#
class GEO
  attr_accessor :lat, :lon
  def initialize(lat, lon)
    @lat = lat
    @lon = lon
  end
  
  def get_n(offset=0.01) # 北側にずらして座標クラスを返す
    return GEO.new(@lat+offset,@lon)
  end
  
  def get_s(offset=0.01) # 南
    return GEO.new(@lat-offset,@lon)
  end
  
  def get_e(offset=0.01) # 東
    return GEO.new(@lat,@lon+offset)
  end
  
  def get_w(offset=0.01) # 西
    return GEO.new(@lat,@lon-offset)
  end
  
  def to_s
    return "#{@lat},#{@lon}"
  end
end

#
#= get_addressline
#== 緯度経度から道情報を返す
#
def get_addressline(geo)
  url = "#{PATH_A}#{geo.to_s}#{PATH_B}"
  doc = Nokogiri.HTML(open(url))
  #return "#{doc}(#{geo.to_s})"
  return "#{doc.xpath(ROUTE_XPATH).text}(#{geo.to_s})"
end

#
#= main
#
lat = 36.260331
lon = 137.439516


#lat.step(38.0, 0.001){ |l|
g = GEO.new(lat, lon)
road_name = get_addressline(g)
puts road_name
#while(1)
  #puts get_addressline(g.get_n)
  #puts get_addressline(g.get_e)
  #puts get_addressline(g.get_w)
  puts get_addressline(g.get_s)
  
#end
#}
