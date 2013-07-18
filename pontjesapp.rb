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
     
    config = JSON.parse(File.read('./config.json'))
    dbconf = config["postgres"]  
    mtkey = config["marinetraffic"]["key"]  
    
    DB = Sequel.connect("postgres://#{dbconf['user']}:#{dbconf['password']}@#{dbconf['host']}/#{dbconf['database']}")
    
    scheduler = Rufus::Scheduler.start_new
    set :scheduler, scheduler
    
    scheduler.every('70s') do
      puts "Downloading vessel positions (msgtype:simple)"
      positions = MarineTraffic.get_simple(mtkey)      
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
        
    scheduler.every('3700s') do
      puts "Downloading extended vessel data (msgtype:extended)"
      vessels = MarineTraffic.get_extended(mtkey)      
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

  get '/' do    
    "Hello World!".to_json
  end

end

module MarineTraffic  

  require 'xmlsimple'
  require 'faraday'

  #http://services.marinetraffic.com/api/exportvesselphoto/f70acefebafee5ba8e65661514b243324789ee05/mmsi:775508000
  # <PHOTO>
  # <PHOTOURL URL="http://services.marinetraffic.com/photos/show/739090"/>
  # </PHOTO>

  @@url = "http://services.marinetraffic.com/api/exportvessels/%s/timespan:%s/protocol:xml/msgtype:%s"
      
  def self.download(key, timespan, msgtype)
    response = Faraday.get @@url % [key, timespan, msgtype]
    XmlSimple.xml_in (response.body)
  end

  def self.get_simple(key)
    data = self.download(key, 2, "simple")    
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

  def self.get_extended(key)
    data = self.download(key, 60, "extended")
    vessels = []
    if data.has_key? "row"      
      data["row"].each { |row|           
        vessels << {
          :mmsi => row["MMSI"].to_i,
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
          :yob => row["YOB"].to_i
        }
      }
    end
    return vessels    
  end

end 