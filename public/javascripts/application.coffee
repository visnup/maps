gmaps = google.maps

gmaps.LatLngBounds.prototype.containsBounds = (latLngBounds) ->
  clone = new gmaps.LatLngBounds @getSouthWest(), @getNorthEast()
  clone.union(latLngBounds).equals(this)

class Me extends Backbone.Model
  initialize: ->
    @getPosition()
    @on 'change:coords', _.debounce(@reverseGeocode, 5000), this

  getLatLng: ->
    coords = @get 'coords'
    new gmaps.LatLng coords.latitude, coords.longitude

  getZoom: ->
    coords = @get 'coords'
    Math.round(coords.accuracy * 0.11 + 10) # 100 = 21; 0 = 10

  getPosition: ->
    geo = navigator.geolocation
    geo.getCurrentPosition (position) =>
      @set position
      @trigger 'reset'
    , null, maximumAge: 60000, timeout: 1000

    geo.watchPosition (position) =>
      @set position

  reverseGeocode: ->
    geocoder = new gmaps.Geocoder
    geocoder.geocode latLng: @getLatLng(), (result, status) =>
      @set name: result[0]?.formatted_address

class Places extends Backbone.Collection
  search: (q, bounds = map.getBounds()) ->
    @reset()
    places = new gmaps.places.PlacesService map
    places.search keyword: q, bounds: bounds, (result, status) =>
      if result.length > 0
        @reset result
      else
        geocoder = new gmaps.Geocoder
        geocoder.geocode address: q, bounds: bounds, (result, status) =>
          @reset result

class Popup extends gmaps.OverlayView
  constructor: (options) ->
    @model = options.model
    @marker = options.marker

    @addListeners()

  addListeners: ->
    gmaps.event.addListenerOnce @marker, 'click', _.bind(@show, this)

  show: ->
    map = @marker.getMap()
    gmaps.event.trigger map, 'click'
    @setMap map
  hide: -> @setMap null

  onAdd: ->
    @$el = $('<div class="popup">')
      .text(@model.get('name') || @model.get('formatted_address'))
      .appendTo(@getPanes().floatPane)
    gmaps.event.addListenerOnce @getMap(), 'click', _.bind(@hide, this)

  onRemove: ->
    @$el.remove()

  draw: ->
    pos = @getProjection().fromLatLngToDivPixel @marker.getPosition()
    @$el.css left: pos.x - @$el.width()/2, top: pos.y

class MeDot extends Backbone.View
  initialize: ->
    @model.on 'change', @render, this

  render: ->
    unless @marker
      @marker = new gmaps.Marker
        icon: 'images/dot.png'
        map: map
      new Popup model: @model, marker: @marker

    @marker.setPosition @model.getLatLng()

    this

class Map extends Backbone.View
  id: 'map'

  events:
    'mousewheel': 'pan'

  initialize: ->
    @createMap()
    @dot = new MeDot model: @model

    @model.on 'reset', @center, this
    @collection.on 'reset', @render, this

  createMap: ->
    window.map = @map = new gmaps.Map @el,
      mapTypeId: gmaps.MapTypeId.ROADMAP
      panControl: false
      scrollwheel: false
    gmaps.event.addListener @map, 'bounds_changed', =>
      @model.set bounds: @map.getBounds()

  pan: (e) ->
    @map.panBy -e.wheelDeltaX, -e.wheelDeltaY
    false

  center: ->
    @map.setCenter @model.getLatLng()
    @map.setZoom @model.getZoom()

  render: ->
    gmaps.event.trigger map, 'click'
    m.setMap(null) for m in @markers? && @markers || []

    bounds = new gmaps.LatLngBounds
    @markers = @collection.map (m) =>
      geometry = m.get 'geometry'

      if geometry.viewport
        bounds.union geometry.viewport
      else
        bounds.extend geometry.location
        #bounds.extend @model.getLatLng()

      marker = new gmaps.Marker
        position: geometry.location
        title: m.get('name') || m.get('formatted_address')
        icon: 'images/pin.png'
        map: map
      new Popup model: m, marker: marker

      marker

    if !bounds.isEmpty()
      @map.fitBounds(bounds) unless map.getBounds().containsBounds(bounds)
      gmaps.event.trigger @markers[0], 'click'

    this

class Controls extends Backbone.View
  events:
    'submit form': 'submit'
    'click button': 'center'

  initialize: ->
    @autocomplete = new gmaps.places.Autocomplete @$('input')[0]
    @model.on 'change:bounds', @setBounds, this

  submit: (e) ->
    e.preventDefault()
    @collection.search @$('input').val()

  center: (e) ->
    e.preventDefault()
    @model.trigger 'reset', e

  setBounds: ->
    @autocomplete.setBounds map.getBounds()

class window.App extends Backbone.Router
  initialize: ->
    @me = new Me
    @places = new Places

    @controls = new Controls
      model: @me
      collection: @places
      el: $('.controls')[0]

    @map = new Map
      model: @me
      collection: @places
    @map.$el.appendTo document.body

    @me.on 'reset', _.once(@parseParams), this

  parseParams: ->
    @params = {}
    for pair in location.search.substring(1).split('&')
      [ k, v ] = pair.split '='
      @params[k] = decodeURIComponent(v).replace(/\+/g, ' ')

    if @params.q
      setTimeout =>
        @places.search @params.q
      , 50
