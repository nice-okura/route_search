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


require "net/http"
require "rubygems"
require "open-uri"
require "nokogiri"
require "pp"

#= Macros
#PATH = "/maps/geo?ll=36.260331,137.439516&output=xml&key=GOOGLE_MAPS_API_KEY&hl=ja&oe=UTF8"
ROOT_URL = "http://maps.google.com"
PATH_A = "http://maps.google.com/maps/geo?ll="
PATH_B = "&output=xml&hl=ja&oe=UTF8"
ROUTE_XPATH = "//addressline"

#
#=== 緯度経度クラス
#
class GEO
  attr_accessor :lat, :lon
  def initialize(lat, lon)
    @lat = lat
    @lon = lon
  end
  
  #
  #= 値が一緒ならtrue
  #
  def equal(g)
    return true if g.lat == @lat && g.lon == @lon
    return false
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
  
  #
  # = 緯度経度表示
  # == Args
  # flg :: falseなら緯度経度表示 trueなら経度緯度表示(Google Earth用)
  #
  def to_s(flg=false)
    return "#{@lat},#{@lon}" unless flg
    return "#{@lon},#{@lat}"
  end  
end

#
#= 軌跡クラス
#
class Route
  attr_reader :name
  def initialize(name, geo)
    @name = name
    @route_points = [geo]
  end
  
  #
  #= GEO追加
  #
  def add_geo(geo)
    p geo
    return false if check_dup(geo)
    @route_points << geo
    return true
  end
  
  #
  #= 1つ前のGEO
  #
  def get_prev_geo
    return @route_points[-1]
  end

  def check_dup(g)
    @route_points.each{ |geo|
      return true if geo.equal(g)
    }
    return false
  end
  #
  #= 全てのGEOを書き出す(KML用)
  #
  def output_all
    @route_points.each{ |g|
      print g.to_s(true)
    }
  end
end

#
#= GEOを進めて，routeにないGEOを返す
#
def progress_geo(g)
  offset = 0.1
  next_geo = get_addressline(g.get_n(offset))
  if next_geo[0] == $road_name && $route.check_dup(next_geo[1]) == false
    return next_geo[1]
  end

  next_geo = get_addressline(g.get_e(offset))
  if next_geo[0] == $road_name && $route.check_dup(next_geo[1]) == false
    return next_geo[1]
  end

  next_geo = get_addressline(g.get_w(offset))
  if next_geo[0] == $road_name && $route.check_dup(next_geo[1]) == false
    return next_geo[1]
  end

  next_geo = get_addressline(g.get_s(offset))
  if next_geo[0] == $road_name && $route.check_dup(next_geo[1]) == false
    return next_geo[1]
  end

  return []
end

#
#= get_addressline
#== 緯度経度から道名称とそのGEOを返す
#
def get_addressline(geo)
  url = "#{PATH_A}#{geo.to_s}#{PATH_B}"
  doc = Nokogiri.HTML(open(url))
  #return "#{doc}(#{geo.to_s})"
  road_name = "#{doc.xpath(ROUTE_XPATH).text}"
  ng = "#{doc.xpath("//placemark[@id='p1']/point/coordinates").text}".split(',')
  new_geo = GEO.new(ng[1].to_f, ng[0].to_f)
  return [road_name, new_geo]
end

#
#= main
#
#pp Nokogiri.HTML(open("http://maps.google.com/maps/geo?ll=36.280331,137.439516&output=xml&key=GOOGLE_MAPS_API_KEY&hl=ja&oe=UTF8"))
lat = 36.280331
lon = 137.439516

g = GEO.new(lat, lon)
#puts g.to_s
road_info = get_addressline(g)
$road_name = road_info[0]
puts $road_name

g = road_info[1]
p road_info[1]
$route = Route.new($road_name, g)
puts g.to_s(true)
=begin
g = progress_geo(g)
puts g.to_s(true)
g = progress_geo(g)
puts g.to_s(true)
=end

while(1)
  ng = progress_geo(g)
  break if $route.add_geo(ng) == false
  puts g.to_s(true)
end
