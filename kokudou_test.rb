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
require "matrix"

#= Macros
#PATH = "/maps/geo?ll=36.260331,137.439516&output=xml&key=GOOGLE_MAPS_API_KEY&hl=ja&oe=UTF8"
ROOT_URL = "http://maps.google.com"
PATH_A = "http://maps.google.com/maps/geo?ll="
PATH_B = "&output=xml&hl=ja&oe=UTF8"
ROUTE_XPATH = "//addressline"

DICT_E = [0, 1]
DICT_NE = [1, 1]
DICT_N = [1, 0]
DICT_NW = [1, -1]
DICT_W = [0, -1]
DICT_SW = [-1, -1]
DICT_S = [-1, 0]
DICR_SE = [-1, 1]


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
  #==== 値が一緒ならtrue
  #
  def equal(geo)
    return true if geo.lat == @lat && geo.lon == @lon
    return false
  end
  
  #==== 指定した方向にずらして座標クラスを返す
  #===== Args
  # lat: -1 : 南方向 0 : ずれなし 1 : 北方向
  # lon: -1 : 西方向 0 : ずれなし 1 : 東方向
  #===== Return
  # GEO
  #
  def get_n(lat, lon, offset=0.01) 
    _lat = offset*lat
    _lon = offset*lon
    return GEO.new(@lat+_lat, @lon+_lon)
  end

  
  #
  #=== self->aの向きを調べる
  #
  def get_dist(a)
    dist = [0, 0]
    d_lat = a.lat - self.lat
    d_lon = a.lon - self.lon

    if d_lat.abs > d_lon.abs
      if d_lat > 0
        dist = DICT_N
      else
        dist = DICT_S
      end
    else
      if d_lon > 0
        dist = DICT_E
      else
        dist = DICT_W
      end
    end
    return dist
  end

  #
  #=== self->a の角度を調べる
  #
  def get_angle(a)
    v1 = self.to_v
    v2 = a.to_v
    v = v2 - v1
    p v
    v0 = VectorDICT_N
    ip = v.inner_product(v0)
    cos = ip/(v0.r*v.r)
    sign = cos < 0 ? -1 : 1
    angle = Math.acos(cos)*(180.0/Math::PI)*sign
    return angle
  end

  #
  #=== Vectorにする((x, y)形式)
  #
  def to_v
    return Vector[@lon, @lat]
  end

  
=begin
  #==== 北東側にずらして座標クラスを返す
  def get_ne(offset=0.01) 
    return GEO.new(@lat+offset, @lon+offset)
  end
  
  #==== 東側にずらして座標クラスを返す
  def get_e(offset=0.01) 
    return GEO.new(@lat,@lon+offset)
  end

  #==== 東南側にずらして座標クラスを返す
  def get_es(offset=0.01) # 南
    return GEO.new(@lat-offset, @lon+offset)
  end
  
  #==== 南側にずらして座標クラスを返す
  def get_s(offset=0.01) # 南
    return GEO.new(@lat-offset,@lon)
  end
  
  
  #==== 南西側にずらして座標クラスを返す
  def get_sw(offset=0.01)
    return GEO.new(@lat-offset, @lon-offset)
  end
  

  #==== 西側にずらして座標クラスを返す
  def get_w(offset=0.01)
    return GEO.new(@lat, @lon-offset)
  end

  #==== 北西側にずらして座標クラスを返す
  def get_nt(offset=0.01)
    return GEO.new(@lat+offset, @lon-offset)
  end
=end
  #
  #=== 緯度経度表示
  #==== Args
  # flg :: falseなら緯度経度表示 trueなら経度緯度表示(Google Earth用)
  #
  def to_s(flg=false)
    return "#{@lat},#{@lon}" unless flg
    return "#{@lon},#{@lat}"
  end  
end

#
#== 軌跡クラス
#
class Route
  attr_reader :name
  def initialize(name, geo)
    @name = name
    @route_points = [geo]
    @dist_angle = 0.0 # 走査してる角度
  end
  
  #
  #=== GEO追加
  #
  def add_geo(geo)
    #p geo
    
    return false if check_dup(geo)
    @route_points << geo
    @dist = @route_points[0].get_dist(geo)
    return true
  end

  #
  #=== GEOを進めて，routeにないGEOを返す
  #
  def progress_geo(g)
    #puts "基準：#{g}"
    start_offset = 0.01

    # 北，北東，東，南東，南，南西，西，北東の順
    dist_array =[DICT_N, DICT_NE, DICT_E, DICT_SE, DICT_S, DICT_SW, DICT_W, DICT_NW]
    case @dist
    when DICT_N
      dist_array =[DICT_N, DICT_NE, DICT_NW]
    when DICT_S
      dist_array =[DICT_SE, DICT_S, DICT_SW]
    when DICT_E
      dist_array =[DICT_NE, DICT_E, DICT_SE]
    when DICT_W
      dist_array =[DICT_SW, DICT_W, DICT_NW]
    end
    p @dist
    start_offset.step(0.5, 0.01){ |offset|
      
      #puts offset
      dist_array.each{ |dist|
        #      p dist
        next_geo = get_addressline(g.get_n(dist[0], dist[1], offset))
        #      puts next_geo[0]
        if next_geo[0] == $road_name && $route.check_dup(next_geo[1]) == false
          #p next_geo[1]
          return next_geo[1]
        end
      }
    }
    puts "progress_geo = []"
    return []
  end

  #
  #=== 角度から走査する方向(配列)を返す
  #
  def get_dist_from_angle(angle)
    case angle
    when angle => -45.0 && angle < 45.0
      # 東方向
      ret_dist = [DICT_NE, DICT_E, DICT_SE]
    when angle => 0.0 && angle < 90.0
      # 北東方向
      ret_dist = [DICT_E, DICT_NE, DICT_N]
    when angle => 45.0 && angle < 135.0
      # 北方向
      ret_dist = [DICT_NE, DICT_N, DICT_NW]
    when angle => 90.0 && angle < 180.0
      # 北西方向
      ret_dist = [DICT_N, DICT_NW, DICT_W]
    when angle =< -135.0 || angle > 135.0
      # 西方向
      ret_dist = [DICT_NW, DICT_W, DICT_SW]
    when angle > -180.0 && angle < -90.0
      # 南西方向
      ret_dist = [DICT_W, DICT_SW, DICT_S]
    when angle => -135.0 && angle < -45.0
      # 南方向
      ret_dist = [DICT_SW, DICT_S, DICT_SE]
    when angle => -90.0 && angle < 0.0
      # 南東方向
      ret_dist = [DICT_S, DICT_SE, DICT_E]
    end
    return ret_dist
  end
  
  #
  #=== 道順にソート(点間距離が最小になるように)
  #
  def sort
    @route_points.each{ |a|
      
    }
  end

  def check_dup(g)
    @route_points.each{ |geo|
      return true if geo.equal(g)
    }
    return false
  end

  #
  #=== 全てのGEOを書き出す(KML用)
  #
  def output_all
    @route_points.each{ |g|
      print "#{g.to_s(true)} "
    }
  end
end



#
#=== get_addressline
#==== 緯度経度から道名称とそのGEOを返す
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
#=== main
#

#pp Nokogiri.HTML(open("http://maps.google.com/maps/geo?ll=36.280331,137.439516&output=xml&key=GOOGLE_MAPS_API_KEY&hl=ja&oe=UTF8"))
lat = 36.280331
lon = 137.439516

g = GEO.new(lat, lon)

road_info = get_addressline(g)
$road_name = road_info[0]
puts $road_name

g = road_info[1]
p road_info[1]
$route = Route.new($road_name, g)
#puts g.to_s(true)

g1 = GEO.new(1, 1)
g2 = GEO.new(-1, -1)

p g1.get_angle(g2)
=begin
while(1)
  g = $route.progress_geo(g)
  break if g == []
  $route.add_geo(g)
#  break if $route.add_geo(ng) == false
  #puts g.to_s(true)
end
=end
$route.output_all
