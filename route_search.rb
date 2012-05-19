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

#=== Macros
#PATH = "/maps/geo?ll=36.260331,137.439516&output=xml&key=GOOGLE_MAPS_API_KEY&hl=ja&oe=UTF8"

#==== googlemapのドメイン
ROOT_URL = "http://maps.google.com" 
#==== PATH前半
PATH_A = "http://maps.google.com/maps/geo?ll="
#==== PATH後半
PATH_B = "&output=xml&hl=ja&oe=UTF8"
#==== 国道検出のXPATH
ROUTE_XPATH = "//addressline"

#==== 方角マクロ
#==== 東
DIRECT_E = [0, 1]
#==== 北東
DIRECT_NE = [1, 1]
#==== 北
DIRECT_N = [1, 0]
#==== 北西
DIRECT_NW = [1, -1]
#==== 西
DIRECT_W = [0, -1]
#==== 南西
DIRECT_SW = [-1, -1]
#==== 南
DIRECT_S = [-1, 0]
#==== 南東
DIRECT_SE = [-1, 1]

#==== 国道重複区間用検出ゆるめフラグ
YURUME = false

#
#=== 緯度経度クラス
#
class GEO
  
  # 緯度,経度
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
  #===== Param::
  # lat: -1 : 南方向 0 : ずれなし 1 : 北方向
  # lon: -1 : 西方向 0 : ずれなし 1 : 東方向
  #===== Return::
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
  def get_direct(a)
    direct = [0, 0]
    d_lat = a.lat - self.lat
    d_lon = a.lon - self.lon

    if d_lat.abs > d_lon.abs
      if d_lat > 0
        direct = DIRECT_N
      else
        direct = DIRECT_S
      end
    else
      if d_lon > 0
        direct = DIRECT_E
      else
        direct = DIRECT_W
      end
    end
    return direct
  end

  #
  #=== self->a の角度を調べる
  #
  def get_angle(a)
    v1 = self.to_v
    v2 = a.to_v
    v = v2 - v1
    v0 = Vector[1, 0]
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
  
  # ルートの名前
  attr_reader :name
  
  # 初期化
  # Param:: name:ルートの名前 geo:初期GEO
  def initialize(name, geo)
    @name = name
    @route_points = [geo]
    @direct_angle = 0.0 # 走査してる角度
  end
  
  #
  #=== GEO追加
  #
  def add_geo(geo)
    #p geo
    
    return false if check_dup(geo)
    @direct_angle = @route_points[-1].get_angle(geo)
    @route_points << geo
    return true
  end

  #
  #=== GEOを進めて，routeにないGEOを返す
  # Param:: g:基点GEO
  # Return:: 次のGEO
  def progress_geo(g)
    #puts "基準：#{g}"
    start_offset = 0.01

    # 北，北東，東，南東，南，南西，西，北東の順
    #direct_array =[DIRECT_N, DIRECT_NE, DIRECT_E, DIRECT_SE, DIRECT_S, DIRECT_SW, DIRECT_W, DIRECT_NW]
    p @direct_angle
    direct_array = get_direct_from_angle(@direct_angle)
    #p direct_array
    start_offset.step(0.5, 0.001){ |offset|
      puts "#{offset}"
      direct_array.each{ |direct|
        #      p direct
        next_geo = get_addressline(g.get_n(direct[0], direct[1], offset))
        #      puts next_geo[0]
        if next_geo[0] == $road_name && $route.check_dup(next_geo[1]) == false
          #p next_geo[1]
          return next_geo[1]
        elsif YURUME && next_geo[0].include?("国道") && $route.check_dup(next_geo[1]) == false
          # ゆるい設定
          return next_geo[1]

        end
      }
    }
    puts "progress_geo = []"
    return []
  end

  #
  #=== 角度から走査する方向(配列)を返す
  # Param:: 角度
  def get_direct_from_angle(angle)
    ret_direct = []
    if angle >= -45.0 and angle < 45.0
      # 東方向
      ret_direct = [DIRECT_NE, DIRECT_E, DIRECT_SE]
    elsif angle >= 0.0 && angle < 90.0
      # 北東方向
      ret_direct = [DIRECT_E, DIRECT_NE, DIRECT_N]
    elsif angle >= 45.0 && angle < 135.0
      # 北方向
      ret_direct = [DIRECT_NE, DIRECT_N, DIRECT_NW]
    elsif angle >= 90.0 && angle < 180.0
      # 北西方向
      ret_direct = [DIRECT_N, DIRECT_NW, DIRECT_W]
    elsif angle <= -135.0 || angle > 135.0
      # 西方向
      ret_direct = [DIRECT_NW, DIRECT_W, DIRECT_SW]
    elsif angle > -180.0 && angle < -90.0
      # 南西方向
      ret_direct = [DIRECT_W, DIRECT_SW, DIRECT_S]
    elsif angle >= -135.0 && angle < -45.0
      # 南方向
      ret_direct = [DIRECT_SW, DIRECT_S, DIRECT_SE]
    elsif angle >= -90.0 && angle < 0.0
      # 南東方向
      ret_direct = [DIRECT_S, DIRECT_SE, DIRECT_E]
    end
    return ret_direct
  end
  
  #
  #=== 道順にソート(点間距離が最小になるように)
  #
  def sort
    @route_points.each{ |a|
      
    }
  end
  
  #
  #=== ルート内に重複するGEOがあるかどうか
  #
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

g1 = GEO.new(36.2046005, 137.5515338)
#g2 = GEO.new(-1, -1)
#p g1.get_angle(g2)

#=begin
while(1)
  g = $route.progress_geo(g)
  break if g == []
  $route.add_geo(g)
  puts g.to_s
#  break if $route.add_geo(ng) == false
  #puts g.to_s(true)
end
#=end
$route.output_all
