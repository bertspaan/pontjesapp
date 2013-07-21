require 'sinatra'
require 'json'

class Pontjesapp < Sinatra::Base
  Sequel::Model.plugin :json_serializer 
  
  before do 
    content_type 'application/json'
  end
  
  after do
    response.headers['Access-Control-Allow-Origin'] = '*'
  end

  configure do
    
    @@boundary = JSON.parse(File.read('./data/boundary.json')) 
    config = JSON.parse(File.read('./config.json'))
    dbconf = config["postgres"]  
    vessels_key = config["marinetraffic"]["vessels_key"]  
    photo_key = config["marinetraffic"]["photo_key"]  
    
    DB = Sequel.connect("postgres://#{dbconf['user']}:#{dbconf['password']}@#{dbconf['host']}/#{dbconf['database']}")
    
    # Get boundary WKB
    
    wkb_sql = <<-SQL
      SELECT ST_SetSRID(ST_GeomFromGeoJSON('%s'), 4326) AS wkb
    SQL
    @@boundary_wkb = DB[wkb_sql % [@@boundary["features"][0]["geometry"].to_json]].first[:wkb]
    
    scheduler = Rufus::Scheduler.start_new
    set :scheduler, scheduler
    
    scheduler.every('70s') do
    #scheduler.every('70s') do
      puts "Downloading vessel positions (msgtype:simple)"
      positions = MarineTraffic.get_vessels_simple(vessels_key)      
      positions.each { |position|           
        position[:geom] = Sequel.function(:ST_SetSRID, Sequel.function(:ST_MakePoint, position[:lon], position[:lat]), 4326)
        position.delete(:lat)
        position.delete(:lon)          
        begin
          DB.transaction do
            DB[:positions].insert(position)
          end
        rescue          
        end          
      }        
    end
        
    #scheduler.every('70s') do
    scheduler.every('3700s') do
      puts "Downloading extended vessel data (msgtype:extended)"
      vessels = MarineTraffic.get_vessels_extended(vessels_key, photo_key)      
      vessels.each { |vessel| 
        begin
          DB.transaction do
            DB[:vessels].insert(vessel)
          end
        rescue          
        end          
      }      
    end
        
  end

  SQL = <<-SQL
    SET TIME ZONE -4;
    SELECT 
      v.mmsi,
      imo,
      v.name,
      t.name AS type,
      callsign,
      code2,
      length,
      width,
      draugth,
      grt,
      dwt,
      yob,
      photo_url,
      speed, 
      course, 
      m.time AT TIME ZONE 'UTC' AS "timestamp", 
      ST_AsGeoJSON(geom) AS geometry,
      ST_Intersects(geom, '#{@@boundary_wkb}') AS in_boundary
    FROM vessels v
    JOIN positions p USING (mmsi)
    JOIN types t ON v.type = t.id
    JOIN (
      SELECT p.mmsi, MAX(time) AS time 
      FROM vessels v 
      JOIN positions p USING (mmsi)
      GROUP BY p.mmsi
      HAVING MAX(time) > now() AT TIME ZONE 'UTC' - interval '1 hour'
      ORDER BY time DESC
    ) AS m
    ON (v.mmsi = m.mmsi AND m.time = p.time)
    ORDER BY m.time DESC
  SQL

  get '/' do
    'Pontjesapp - server'.to_json
  end
  
  get '/ships.json' do
    features = []
    DB[SQL].each do |row|
      geometry = JSON.parse(row[:geometry])
      row.delete(:geometry)
      features << { 
        :type => "Feature",
        :geometry => geometry,
        :properties => row.reject { |key,value| value == 0 || value == nil }
      }
    end
    { 
      :type => "FeatureCollection",
      :features => features
    }.to_json
  end
  
  get '/ships_in_boundary.json' do
    @@boundary_wkb
    
  end
  
  get '/boundary.json' do
    @@boundary.to_json
  end
  

end

module MarineTraffic  

  require 'xmlsimple'
  require 'faraday'

  @@photo_url = "http://services.marinetraffic.com/api/exportvesselphoto/%s/mmsi:%s"
  @@vessels_url = "http://services.marinetraffic.com/api/exportvessels/%s/timespan:%s/protocol:xml/msgtype:%s"
      
  @@debug = false
  
  def self.download(url)
    response = Faraday.get url
    XmlSimple.xml_in (response.body)
  end
  
  def self.get_photo_url(photo_key, mmsi)
    data = self.download(@@photo_url % [photo_key, mmsi])
    url = data["PHOTOURL"][0]["URL"] rescue nil 
    if url and url =~ /^.*\d+$/
      return url      
    else
      return nil
    end
  end
  
  def self.get_vessels(vessels_key, timespan, msgtype)
    if @@debug
      file = File.open("data/test/marinetraffic/#{msgtype}.xml", "rb")
      XmlSimple.xml_in file.read
    else
      self.download(@@vessels_url % [vessels_key, timespan, msgtype])
    end
  end

  def self.get_vessels_simple(vessels_key)
    data = self.get_vessels(vessels_key, 5, "simple")    
    positions = []
    if data.has_key? "row"      
      data["row"].each { |row|           
        positions << {
          :mmsi => row["MMSI"].to_i,
          :speed => row["SPEED"].to_i,
          :status => row["STATUS"].to_i,
          :course => row["COURSE"].to_i,
          :time => row["TIMESTAMP"],
          :lon => row["LON"], 
          :lat => row["LAT"]
        }
      }
    end
    return positions       
  end

  def self.get_vessels_extended(vessels_key, photo_key)
    data = self.get_vessels(vessels_key, 60, "extended")
    vessels = []
    if data.has_key? "row"      
      data["row"].each { |row|
        mmsi = row["MMSI"].to_i
        photo_url = self.get_photo_url(photo_key, mmsi)
        vessels << {
          :mmsi => mmsi,
          :name => row["SHIPNAME"],
          :type => row["SHIPTYPE"].to_i,
          :imo => row["IMO"].to_i,
          :callsign => row["CALLSIGN"],
          :code2 => row["CODE2"],
          :length => row["LENGTH"].to_i,
          :width => row["WIDTH"].to_i,
          :draugth => row["DRAUGHT"].to_i,
          :grt => row["GRT"].to_i,
          :dwt => row["DWT"].to_i,
          :yob => row["YOB"].to_i,
          :photo_url => photo_url
        }
      }
    end
    return vessels    
  end

end 