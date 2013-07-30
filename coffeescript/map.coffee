Map = (options) ->
  @styles = {}
  that = this
  @options = _.extend(
    draw: false
    style: "popup"
    
    #layerUrl,
    startLat: 0
    startLng: 0
    startZoom: 8
  , options)
  
  #this.markers = {};
  @markerLayer = new L.FeatureGroup()
  @drawMap = ->
    
    # Create the map
    @map = new L.Map(@options.id,
      center: new L.LatLng(@options.startLat, @options.startLng)
      zoom: @options.startZoom
      layers: new L.TileLayer(@options.layerUrl)
    )
    @markerLayer.addTo @map
    
    # Add the geosearch control
    unless @options.geosearch is `undefined`
      settings = _.extend((if @options.geosearch.settings is `undefined` then {} else @options.geosearch.settings),
        zoomLevel: 15
      )
      settings.provider = new L.GeoSearch.Provider[@options.geosearch.provider]()
      new L.Control.GeoSearch(settings).addTo @map
      @map.on "geosearch_showlocation", (e) ->
        
        # @todo!
        that.updateLocation new L.LatLng(e.Location.Y, e.Location.X)

    console.log @options
    # Add the locate button
    unless @options.locate is `undefined`
      locateUser = ->
        @map.locate settings
      settings = _.extend((if @options.locate.settings is `undefined` then {} else @options.locate.settings),
        setView: true
        maxZoom: 15
      )
      jQuery(@options.locate.html).bind "click", (e) ->
        that.map.locate settings
      .appendTo "#map .leaflet-top.leaflet-center"

    return

  @updateLocation = (latlng) ->
    @location = latlng
    $(@options.updateSelector).trigger "locationUpdate"

  @drawMarkers = (data) ->
    @markerLayer.clearLayers()
    
    # Re-order data array by distance to this.location
    location = (if @location isnt `undefined` then @location else @map.getCenter())
    _.each data, (item, index) ->
      item.id = index
      item.distance = that.meters2miles(location.distanceTo(new L.LatLng(item.Latitude, item.Longitude)))

    data.sort (a, b) ->
      a.distance - b.distance

    # Add new markers and update results
    $results = $(@options.resultsSelector)
    activeColor = (if (activeTab? and activeTab isnt "All Types") then _.filter(@options.tabs, (tab) ->
      tab.title is activeTab
    )[0].color else false)

    # Cycle through each item and add a marker
    $results.html ""
    _.each data, (item, index) ->
      if item.Latitude isnt `undefined` and item.Longitude isnt `undefined` and index <= 25

        # Build the fields html
        item.fields = ""
        item.primaryFields = ""
        _.each that.options.fields, (field) ->
          if item[field.col]? and item[field.col] isnt ""
            val = (if (typeof item[field.col] is "string") then item[field.col] else item[field.col].join(", "))
            html = ich.fieldItem(
              label: field.label
              value: val
              primary: (if field.primary then "primary" else "not-primary")
            ,
            true)
            item.fields += html
            item.primaryFields += html if field.primary

        # Add the marker
        item.color = (if activeColor then activeColor else that.iconColor(item["Services Provided"]))
        item["Phone Number"] = item["Phone Number"] + " |" if item["Phone Number"] isnt ""
        
        marker = L.marker([item.Latitude, item.Longitude],
          icon: L.AwesomeMarkers.icon(
            text: index
            textFormat: "letter"
            color: item.color
          )
          title: item["Clinic Name"]
        )

        .bindPopup(ich.popupItem(item).html(),
          closeButton: true
        )

        .on("popupopen", (e) ->
          console.log e
          $item = $results.find(".item[rel=" + @_leaflet_id + "]")
          $item.addClass "active"
          $("html, body").animate
            scrollTop: $item.offset().top - 60
          , 1000
        )

        .on("popupclose", (e) ->
          $item = $results.find(".item[rel=" + @_leaflet_id + "]")
          $item.removeClass "active"
        )

        .addTo(that.markerLayer)
        
        # Add the item to the results sidebar
        item.id = marker._leaflet_id
        item.letter = marker.options.icon.num2letter(index)
        item.distance = Math.round(item.distance * 10) / 10
        $resultItem = ich.listItem(item)
        $resultItem.find(".static-marker, h3 a").bind "click", ->
          marker = that.markerLayer._layers[$(this).parents(".item").attr("rel")]
          marker.openPopup()
          that.map.panTo(marker._latlng)
          false

        $results.append $resultItem

    $(@options.updateSelector).addClass "left-sidebar-active"
    @lastBounds = @map.getBounds()
    return


  @markerBounds = (bounds, factor) ->
    factor = factor? ? factor-1 : 1
    lat = Math.abs(bounds._southWest.lat - bounds._northEast.lat) * factor
    lng = Math.abs(bounds._southWest.lng - bounds._northEast.lng) * factor
    "_southWest":
      lat: bounds._southWest.lat - lat
      lng: bounds._southWest.lng - lng
    "_northEast":
      lat: bounds._northEast.lat + lat
      lng: bounds._northEast.lng + lng


  @iconColor = (services) ->
    color = ""
    if typeof services is "object"
      service = services[0]
      _.each @options.tabs, (tab) ->
        color = tab.color  unless tab.services.indexOf(service) is -1
    color


  @meters2miles = (meters) ->
    meters * 0.00062137

  if @options.draw
    @drawMap()
    @drawMarkers @options.draw  unless typeof @options.draw is "boolean"
  
  @
  