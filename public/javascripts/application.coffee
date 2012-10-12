

# google map extensions

gmaps = google.maps

gmaps.LatLngBounds.prototype.containsBounds = (latLngBounds) ->
  clone = new gmaps.LatLngBounds @getSouthWest(), @getNorthEast()
  clone.union(latLngBounds).equals(this)

class PopupOverlay extends gmaps.OverlayView
  constructor: (options) ->
    @text = options.text
    @marker = options.marker
    @model = options.model

    @model.on 'change:checked', @setStar, this

  onAdd: ->
    @$el = $('<div class="popup">')
      .text(@text || '?')
      .prepend('<i class="icon-star-empty"></i>')
      .appendTo(@getPanes().floatPane)
    @setStar()

    @$el.on 'click i', (e) =>
      e.stopPropagation()
      @model.save checked: !@model.get('checked')

  draw: ->
    pos = @getProjection().fromLatLngToDivPixel @marker.getPosition()
    @$el.css left: pos.x - @$el.width()/2, top: pos.y

  onRemove: ->
    @$el.remove()

  setText: (@text) ->
    @$el?.text @text

  setStar: ->
    checked = @model.get 'checked'
    @$el.find('i')
      .toggleClass('icon-star', checked)
      .toggleClass('icon-star-empty', !checked)


# models

Backbone.Model.prototype.idAttribute = '_id'

class Place extends Backbone.Model
  defaults:
    selected: false

  initialize: ->
    if latLng = @attributes.latLng
      @set geometry: { location: new gmaps.LatLng latLng[0], latLng[1] }
    else if latLng = @getLatLng()
      @set latLng: [ latLng.Xa, latLng.Ya ]

  getTitle: -> @get('name') || @get('formatted_address')
  getLatLng: -> @get('geometry')?.location

class Me extends Place
  initialize: ->
    @getPosition()
    @on 'change:coords', @reverseGeocode, this

  getLatLng: ->
    if coords = @get 'coords'
      new gmaps.LatLng coords.latitude, coords.longitude

  getZoom: ->
    if coords = @get 'coords'
      Math.round(coords.accuracy * 0.11 + 10) # 100 = 21; 0 = 10

  getPosition: ->
    geo = navigator.geolocation
    geo.getCurrentPosition (position) =>
      @set position
      @trigger 'reset'
    , null, maximumAge: 60000, timeout: 1000

    geo.watchPosition (position) =>
      @set position

  reverseGeocode:
    _.debounce ->
      geocoder = new gmaps.Geocoder
      geocoder.geocode latLng: @getLatLng(), (result, status) =>
        @set name: result[0]?.formatted_address
    , 5000, true

class Places extends Backbone.Collection
  url: '/favorites'
  model: Place

  initialize: ->
    @on 'change:selected', @selectOne, this

  selected: ->
    @find (model) -> model.get('selected')

  selectOne: (model, selected) ->
    if selected
      for m in @models
        m.set selected: false if m != model && m.get('selected')

  getBounds: ->
    @reduce (bounds, model) ->
      if geometry = model.get 'geometry'
        if geometry.viewport
          bounds.union geometry.viewport
        else
          bounds.extend geometry.location
      bounds
    , new gmaps.LatLngBounds

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


# views

class Marker extends Backbone.View
  initialize: ->
    @options.icon ||= 'images/pin.png'

    @model.on 'change', @render, this
    @model.on 'change:name', @onNameChange, this
    @model.on 'change:selected', @onSelectedChange, this

    @create()

  render: ->
    @marker.setPosition @model.getLatLng()
    this

  create: ->
    @marker = new gmaps.Marker
      title: @model.getTitle()
      icon: @options.icon
      position: @model.getLatLng()
      map: map
    @overlay = new PopupOverlay
      text: @model.getTitle()
      marker: @marker
      model: @model

    gmaps.event.addListener @marker, 'click', =>
      @model.set selected: true

  remove: ->
    @marker.setMap null
    @overlay.setMap null

  onNameChange: (model, name) ->
    @overlay.setText name

  onSelectedChange: (model, selected) ->
    @overlay.setMap(if selected then @marker.getMap() else null)

class Map extends Backbone.View
  id: 'map'

  events:
    'mousewheel': 'pan'

  initialize: ->
    @createMap()
    @dot = new Marker
      model: @model
      icon: 'images/dot.png'

    @model.on 'reset', @locate, this
    @collection.on 'reset', @render, this

  createMap: ->
    window.map = @map = new gmaps.Map @el,
      mapTypeId: gmaps.MapTypeId.ROADMAP
      panControl: false
      scrollwheel: false

    gmaps.event.addListener @map, 'bounds_changed', =>
      @model.set bounds: @map.getBounds()
    gmaps.event.addListener @map, 'click', =>
      @clickTimeout = setTimeout =>
        @model.set selected: false
        @collection.invoke 'set', selected: false
      , 300
    gmaps.event.addListener @map, 'dblclick', =>
      clearTimeout @clickTimeout

  pan: (e) ->
    @map.panBy -e.wheelDeltaX, -e.wheelDeltaY
    false

  locate: ->
    center = if @map.getCenter() then 'panTo' else 'setCenter'
    @map[center] @model.getLatLng()
    @map.setZoom @model.getZoom()

  render: ->
    _.invoke @markers, 'remove'
    @markers = @collection.map (model) -> new Marker model: model

    if !(bounds = @collection.getBounds()).isEmpty()
      @map.fitBounds(bounds) unless map.getBounds()?.containsBounds(bounds)
      @collection.first()?.set selected: true

    this

class Controls extends Backbone.View
  events:
    'submit form.search': 'search'
    'click button.locate': 'locate'
    'click button.favorites': 'favorites'

  initialize: ->
    @autocomplete = new gmaps.places.Autocomplete @$('input')[0]

    @model.on 'change:bounds', @onBoundsChange, this
    @collection.on 'change:selected', @onSelectedChange, this

  search: (e) ->
    e.preventDefault()
    @collection.search @$('input').val()

  locate: (e) ->
    @model.trigger 'reset', e

  favorites: (e) ->
    @collection.fetch()

  onBoundsChange: ->
    @autocomplete.setBounds map.getBounds()

  onSelectedChange: ->
    @$('[name=to]').val @collection.selected()?.get('name')

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

    @me.on 'change:selected', (model, selected) =>
      @places.invoke 'set', selected: false if selected
    @places.on 'change:selected', (model, selected) =>
      @me.set selected: false if selected

    @places.fetch()

  parseParams: ->
    @params = {}
    for pair in location.search.substring(1).split('&')
      [ k, v ] = pair.split '='
      @params[k] = decodeURIComponent(v).replace(/\+/g, ' ')

    if @params.q
      setTimeout =>
        @places.search @params.q
      , 50
