gmaps = google.maps

class Me extends Backbone.Model
  initialize: ->
    geo = navigator.geolocation
    geo.getCurrentPosition (position) =>
      @set position
      @trigger 'reset'
    , ->
      console.log arguments
    , maximumAge: 60000, timeout: 1000

    geo.watchPosition (position) =>
      @set position

  getLatLng: ->
    coords = @get 'coords'
    new gmaps.LatLng coords.latitude, coords.longitude

  getZoom: ->
    coords = @get 'coords'
    Math.round(coords.accuracy * 0.11 + 10) # 100 = 21; 0 = 10

class Markers extends Backbone.Collection
  search: (q, bounds = map.getBounds()) ->
    console.log 'search:', q, bounds
    places = new gmaps.places.PlacesService map
    places.search keyword: q, bounds: bounds, (result, status) =>
      console.log result
      if result.length > 0
        @reset result
      else
        geocoder = new gmaps.Geocoder
        geocoder.geocode address: q, bounds: bounds, (result, status) =>
          console.log result
          @reset result

class MeDot extends Backbone.View
  initialize: ->
    @model.on 'change', @render, this

  render: ->
    @marker ||= new gmaps.Marker
      icon: 'images/dot.png'
      map: map
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
    og = e.originalEvent
    @map.panBy -og.wheelDeltaX, -og.wheelDeltaY
    false

  center: ->
    @map.setCenter @model.getLatLng()
    @map.setZoom @model.getZoom()

  render: ->
    m.setMap(null) for m in @markers? && @markers || []

    bounds = new gmaps.LatLngBounds
    @markers = @collection.map (m) =>
      geometry = m.get 'geometry'

      if geometry.viewport
        bounds.union geometry.viewport
      else
        bounds.extend geometry.location
        bounds.extend @model.getLatLng()

      console.log m
      new gmaps.Marker
        position: geometry.location
        title: m.get('name') || m.get('formatted_address')
        icon: 'images/pin.png'
        map: map

    current = map.getBounds()
    current = new gmaps.LatLngBounds current.getSouthWest(), current.getNorthEast()
    unless bounds.isEmpty() || current.union(bounds).equals(map.getBounds())
      @map.fitBounds bounds

    this

class Controls extends Backbone.View
  events:
    'submit form': 'submit'
    'click button': 'center'

  initialize: ->
    @autocomplete = new gmaps.places.Autocomplete @$(':text')[0]
    @model.on 'change:bounds', @setBounds, this

  submit: (e) ->
    e.preventDefault()
    @collection.search @$(':text').val()

  center: (e) ->
    e.preventDefault()
    @model.trigger 'reset', e

  setBounds: ->
    @autocomplete.setBounds map.getBounds()

class window.App extends Backbone.Router
  initialize: ->
    @me = new Me
    @markers = new Markers

    @controls = new Controls
      model: @me
      collection: @markers
      el: $('.controls')[0]

    @map = new Map
      model: @me
      collection: @markers
    @map.$el.appendTo document.body

    @me.on 'reset', _.once(@parseParams), this

  parseParams: ->
    @params = {}
    for pair in location.search.substring(1).split('&')
      [ k, v ] = pair.split '='
      @params[k] = decodeURIComponent(v).replace(/\+/g, ' ')

    if @params.q
      setTimeout =>
        @markers.search @params.q
      , 50
