Tower.Router = Ember.Router.extend
  urlForEvent: (eventName, contexts...) ->
    path = @._super(eventName, contexts...);
    if path == ''
      path = '/'
    path
  initialState: 'root'
  # @todo 'history' throws an error in ember
  location:     Ember.HistoryLocation.create()
  root:         Ember.Route.create
    route: '/'
    index: Ember.Route.create(route: '/')
    eventTransitions:
      showRoot: 'root.index'
    showRoot: Ember.State.transitionTo('root.index')

  # Don't need this with the latest version of ember.
  handleUrl: (url, params = {}) ->
    route = Tower.NetRoute.findByUrl(url)

    if route
      params = route.toControllerData(url, params)
      Tower.router.transitionTo(route.state, params)
    else
      console.log "No route for #{url}"

  # createStatesByRoute(Tower.router, 'posts.show.comments.index')
  createControllerActionState: (name, action, route) ->
    name = _.camelize(name, true) #=> postsController

    # @todo tmp hack
    #if action == 'show' || action == 'destroy' || action == 'update'
    #  route += ':id'
    #else if action == 'edit'
    #  route += ':id/edit'

    # isIndexActive, isShowActive
    # actionMethod  = "#{action}#{_.camelize(name).replace(/Controller$/, '')}"
    # 
    # Tower.router.indexPosts = Ember.State.transitionTo('root.posts.index')
    # Need to think about this more...
    # Tower.router[actionMethod] = Ember.State.transitionTo("root.#{_.camelize(name, true).replace(/Controller$/, '')}.#{action}")

    Ember.Route.create
      route: route

      # So you can give it a post and it returns the attributes
      #
      # @todo
      serialize: (router, context) ->
        attributes  = context.toJSON() if context && context.toJSON
        attributes || context # i.e. "params"

      deserialize: (router, params) ->
        params

      enter: (router, transition) ->
        @_super(router, transition)

        console.log "enter: #{@name}" if Tower.debug
        controller  = Ember.get(Tower.Application.instance(), name)

        if controller
          if @name == controller.collectionName
            controller.enter()
          else
            controller.enterAction(action)

      connectOutlets: (router, params) ->
        console.log "connectOutlets: #{@name}" if Tower.debug
        controller  = Ember.get(Tower.Application.instance(), name)

        # controller.call(router, @, params)
        # if @action == state.name, call action
        # else if state.name == @collectionName call @enter
        if controller
          return if @name == controller.collectionName
          controller.call(router, params)

        true

      exit: (router, transition) ->
        @_super(router, transition)

        console.log "exit: #{@name}" if Tower.debug
        controller  = Ember.get(Tower.Application.instance(), name)

        if controller
          if @name == controller.collectionName
            controller.exit()
          else
            controller.exitAction(action)
  insertRoute: (route) ->
    
    return undefined unless _.include(route.methods, "GET") && route.options.action? # we only care about the GET methods for ember also lets assume a action is designated, to weed out non ember get routes / we can clean this up and maybe use a different identified
    
    #IMO - Paths should be calculated from the url rather than calculating the URL from the path
      #if route.state 
      #  path = route.state
      #else
      #  path = []
      #  route.path.replace /\/([^\/]+)/g, (_, $1) ->
      #    path.push($1.split('.')[0])

      #  path = path.join('.')
    
      #return undefined if !path || path == ""
    #/IMO
    
    routeName = route.options.path.replace(".:format?", "")
    
    #get all components of our route
    
    urlPieces = routeName.split('/')     
   
    urlPieces = _.reject urlPieces, (piece)  -> piece is ""
    namespaces = urlPieces[0...(urlPieces.length-1)]

    
    c = 0
    
    #find or create name spaces
    controllerName = route.controller.name
    state = @root
    
    routeNameSpaceHash = {}
    
    statePath = ["root"]
    
    #build out or traverse the namespace to the action we are creating
    
    #names space is the (/blogs/posts) parts of /blogs/posts/:id for example
    
    for namespace in namespaces
      states = Ember.get(state, 'states')
      if !states
        states = {}
        Ember.set(state, 'states', states)
        
      ns = namespace.replace(":", "")
      s = Ember.get(states, ns)
      #console.log(state.name)
      if s
        state = s
      else
        routePath = '/'
        routePath += namespace
        s = @createControllerActionState(controllerName, "index", routePath) 
        state.setupChild(states, ns, s)
        #console.log(state)
        #console.log("ns was: " + state.name, "ns will be: " + s.name)
        state = s
        
        
      statePath.push(state.name);

    
    states = Ember.get(state, 'states')
    if !states
      states = {}
      Ember.set(state, 'states', states)
    

    #i am in the root ns everything that isnt a namespace at the level would be an index route
    methodName = route.options.name
    stateName = route.state
  
    targetSegment = urlPieces[urlPieces.length - 1]
    myAction = route.options.action if route.options.action?
    children = state.get('childStates')
    #console.log(children)
    s = _.find children, (state) -> state.name == targetSegment
    #console.log(children, s, targetSegment)
    if targetSegment?
      statePath = [] 
      statePath = [targetSegment] if namespaces.length == 0
    statePath.push(myAction)
  
    statePath = statePath.join(".")
    

    

    if !s
      isRoot = !targetSegment?
      targetSegment = "root" unless targetSegment?
      routePath = '/' 
      routePath += targetSegment unless isRoot
    
      
      states = Ember.get(state, 'states')
      if !states
        states = {}
        Ember.set(state, 'states', states)
      s = @createControllerActionState(controllerName, myAction, routePath)
      if namespaces.length == 0
        state.setupChild(states, targetSegment, s) 
      else
        state.setupChild(states, targetSegment.replace(":", ""), s)
      state = s
      
      #if namespaces.length == 0 #handle root indexes
      states = Ember.get(state, 'states')
      if !states
        states = {}
        Ember.set(state, 'states', states)
      
      s = @createControllerActionState(controllerName, myAction, '/') #this where we want to land usually for actions, why?
      state.setupChild(states, myAction, s)
      state = s if namespaces.length > 0 #not index?
    
    #walk up state tree and build a name
    pState = state
    pathTree = []
    while true
      pState = pState.parentState
      break if !pState? || !pState.name?
      pathTree.push(pState.name)
    
    pathNamespace = pathTree.reverse().join(".")
    statePath = "#{pathNamespace}.#{statePath}" if pathNamespace != ""
    console.log(statePath)
      
    Tower.router.root[methodName] = Ember.State.transitionTo(statePath)
    Tower.router.root.eventTransitions[methodName] = statePath

    undefined

# @todo tmp workaround b/c ember will initialize url right when router is created
Tower.router = Tower.Router.PrototypeMixin.mixins[Tower.Router.PrototypeMixin.mixins.length - 1].properties
