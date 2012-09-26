_ = Tower._

# @mixin
Tower.ModelSerialization =
  # Compile the model instance into a hash.
  #
  # @param [Object] options
  # @option options [Array] only the only properties you want in the JSON object.
  # @option options [Array] except the properties you don't want in the JSON object.
  # @option options [Array] methods the methods you want called and added to the JSON object.
  #
  # @return [Object]
  toJSON: (options) ->
    @_serializableHash(options)

  # Return a copy of this model with the same attributes, except for the id.
  #
  # @return [Tower.Model]
  clone: ->
    # need to get a clone method that works on arrays
    attributes = _.clone(@toJSON())
    delete attributes.id
    
    for key, value of attributes
      attributes[key] = value.concat() if _.isArray(value)

    @constructor.build(attributes)

  # Implementation of the {#toJSON} method.
  #
  # @private
  _serializableHash: (options = {}) ->
    result = {}
    fields = @get('fields')

    attributeNames = _.keys(@constructor.fields())

    if only = options.only
      attributeNames = _.union(_.toArray(only), attributeNames)
    else if except = options.except
      attributeNames = _.difference(_.toArray(except), attributeNames)

    if fields && fields.length
      fields.push('id')
      attributeNames = _.intersection(attributeNames, fields)

    for name in attributeNames
      result[name] = @_readAttributeForSerialization(name)

    cid = @_readAttributeForSerialization('_cid')
    if cid?
      result._cid = cid
      if result.id == cid
        delete result.id

    if methods = options.methods
      methodNames = _.toArray(methods)
      for name in methods
        result[name] = @[name]()

    # TODO: async!
    if includes = options.include
      includes  = _.toArray(includes)
      for include in includes
        unless _.isHash(include)
          tmp           = {}
          tmp[include]  = {}
          include       = tmp
          tmp           = undefined

        for name, opts of include
          records = @[name]().all()
          for record, i in records
            records[i] = record._serializableHash(opts)
          result[name] = records

    # @todo think about this more
    # for key, value of result
    #   delete result[key] unless value?

    result

  # @private
  _readAttributeForSerialization: (name, type = 'json') ->
    @get(name)

module.exports = Tower.ModelSerialization
