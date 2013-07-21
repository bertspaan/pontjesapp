Sequel.migration do

	up do

    $stderr.puts("Creating tables...")    
    
    create_table :vessels do
      bigint :mmsi, :primary_key => true      
      String :name
      integer :type
      integer :imo
      String :callsign
      String :code2
      integer :length
      integer :width
      integer :draugth
      integer :grt
      integer :dwt
      integer :yob
      String :photo_url
    end
    
    # CURRENT_PORT="WILLEMSTAD" 
    # LAST_PORT="WILLEMSTAD" 
    # LAST_PORT_TIME="2013-07-18T09:05:00" 
    # DESTINATION="WILLEMSTAD" 
    # ETA="2013-07-15T08:00:00"
    # 
    # LAT="12.109880"
    # LON="-68.933212"
    # SPEED="0" 
    # COURSE="35"    
    
    create_table :positions do
      bigint :mmsi
      integer :speed
      integer :status
      integer :course
      timestamp :time
      column :geom, 'geometry'      
      primary_key [:mmsi, :time]
    end
    
    # Indexes and constraints
    
    run <<-SQL
      ALTER TABLE positions ADD CONSTRAINT constraint_geom_4326 CHECK (ST_SRID(geom) = 4326);
      CREATE INDEX ON positions USING btree (mmsi);
      CREATE INDEX ON positions USING btree (time);
      CREATE INDEX ON positions USING gist (geom);
    SQL
    
    create_table :types do 
      bigint :id, :primary_key => true
      String :name
    end
    
	end
	
	down do
		drop_table(:vessels)
		drop_table(:positions)
		drop_table(:types)
	end
end
