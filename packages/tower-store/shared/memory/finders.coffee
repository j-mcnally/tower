_ = Tower._

# @mixin
Tower.StoreMemoryFinders =
  # @see Tower.Store#find
  find: (cursor, callback) ->
    result      = []
    records     = @records.toArray()
    conditions  = cursor.conditions()

    usingGeo    = @_conditionsUseGeo(conditions)

    # If $near, calculate and add __distance to all records. Remove $near from conditions
    if usingGeo
      @_calculateDistances(records, @_getCoordinatesFromConditions(conditions))
      @_prepareConditionsForTesting(conditions)

    if _.isPresent(conditions)
      for record in records
        result.push(record) if Tower.StoreOperators.test(record, conditions)
    else
      for record in records
        result.push(record)

    sort        = if usingGeo then @_getGeoSortCriteria() else cursor.getCriteria('order')
    limit       = cursor.getCriteria('limit')# || Tower.Store.defaultLimit
    startIndex  = cursor.getCriteria('offset') || 0

    result    = @sort(result, sort) if sort.length

    endIndex  = startIndex + (limit || result.length) - 1

    result    = result[startIndex..endIndex]

    result    = callback.call(@, null, result) if callback

    result

  # @see Tower.Store#findOne
  findOne: (cursor, callback) ->
    record = undefined

    cursor.limit(1)

    @find cursor, (error, records) =>
      record = records[0] || null
      callback.call(@, error, record) if callback

    record

  # @see Tower.Store#count
  count: (cursor, callback) ->
    result = undefined

    @find cursor, (error, records) =>
      result = records.length
      callback.call(@, error, result) if callback

    result

  # @see Tower.Store#exists
  exists: (cursor, callback) ->
    result = undefined

    @count cursor, (error, record) =>
      result = !!record
      callback.call(@, error, result) if callback

    result

  # store.sort [{one: 'two', hello: 'world'}, {one: 'four', hello: 'sky'}], [['one', 'asc'], ['hello', 'desc']]
  sort: (records, sortings) ->
    _.sortBy(records, sortings...)

  # TODO: Unhardcode coordinates field
  _getCoordinatesFromConditions: (conditions) ->
    conditions.coordinates['$near'] if _.isObject(conditions) && conditions.coordinates?

  _getGeoSortCriteria: ->
    [['__distance','asc']]

  # TODO: Unhardcode coordinates field
  _calculateDistances: (records, nearCoordinate) ->
    center = {latitude: nearCoordinate.lat, longitude: nearCoordinate.lng}
    for record in records
      coordinates = record.get('coordinates')
      coordinates = {latitude: coordinates.lat, longitude: coordinates.lng}

      record.__distance = Tower.module('geo').getDistance(center, coordinates)

  # Adjusts the given conditions so they can be used
  _prepareConditionsForTesting: (conditions) ->
    return unless _.isHash(conditions) && _.isHash(conditions.coordinates)
    delete conditions.coordinates['$near']

  _conditionsUseGeo: (conditions) ->
    return false unless _.isHash(conditions)
    return true for key, value of conditions when _.isHash(value) && (_.isPresent(value['$near']) || _.isPresent(value['$maxDistance']))

# @todo move this to client folder
if Tower.isClient
  Tower.StoreMemoryFinders.fetch = (cursor, callback) ->
    method = if cursor._limit == 1 then 'findOne' else 'find'
    if Tower.NetConnection.transport
      Tower.NetConnection.transport[method] cursor, (error, records) =>
        #records = @load(records)
        if callback
          callback(error, records)
        else if Tower.debug
          console.log(records)

        records
    else
      @[method](cursor, callback)

module.exports = Tower.StoreMemoryFinders
