describe 'hybind', ->
  Q = require 'q'

  beforeEach ->
    @hybind = require './index.coffee'
    @api = @hybind 'http://localhost'
    @john = name: 'john'
    @http = jasmine.createSpy('http').andReturn Q()
    @hybind.http = @http

  describe 'root api', ->
    it 'should have self link', ->
      expect(@api._links.self.href).toBe 'http://localhost'
    it 'should have $bind function', ->
      expect(typeof @api.$bind).toBe 'function'

  describe '$bind', ->
    describe 'without object', ->
      it 'should create a property object', ->
        @api.$bind 'hello'
        expect(typeof @api.hello).toBe 'object'
      it 'should have a matching self link', ->
        obj = @api.$bind 'hello'
        expect(obj._links.self.href).toBe 'http://localhost/hello'
      it 'should have an overridable url', ->
        obj = @api.$bind 'hello', 'http://remotehost'
        expect(obj._links.self.href).toBe 'http://remotehost'

    describe 'with object', ->
      it 'should create a self link with given link', ->
        @api.$bind @john, 'j'
        expect(@john._links.self.href).toBe 'http://localhost/j'
      it 'should create a self link with default id function', ->
        @api.$id () -> 'jo'
        @api.$bind @john
        expect(@john._links.self.href).toBe 'http://localhost/jo'
      it 'should create a self link with custom id function', ->
        @api.$bind @john, (x) -> x.name
        expect(@john._links.self.href).toBe 'http://localhost/john'
      it 'should have an overridable url', ->
        @api.$bind @john, null, 'http://remotehost'
        expect(@john._links.self.href).toBe 'http://remotehost'
      it 'should fail if id function is missing', ->
        api = @api
        expect(-> api.$bind @john).toThrow 'No id function defined'

    describe 'collections', ->
      it 'should be supported as parameter', ->
        addresses = []
        @api.$bind addresses, 'addresses'
        expect(addresses._links.self.href).toBe 'http://localhost/addresses'
      it 'should be supported as property', ->
        addresses = []
        @api.$bind 'addresses', addresses
        expect(@api.addresses).toBe addresses

  describe 'operations on objects', ->
    beforeEach ->
      @api.$bind @john, 'john'

    describe '$load', ->
      it 'should issue a GET request', ->
        @john.$load()
        expect(@http).toHaveBeenCalledWith jasmine.objectContaining
          method: 'GET', url: 'http://localhost/john'

      it 'should support parameters', ->
        @john.$load p: true
        expect(@http).toHaveBeenCalledWith jasmine.objectContaining
          method: 'GET', url: 'http://localhost/john?p=true'
        @http.reset()
        @api.$bind("paul?v=1").$load p: true
        expect(@http).toHaveBeenCalledWith jasmine.objectContaining
          method: 'GET', url: 'http://localhost/paul?v=1&p=true'

      it 'should replace the object content but not remove the $ functions and links', (done) ->
        @http.andReturn Q age: 22
        john = @john
        john.$load().then (newJohn) ->
          expect(john).toBe newJohn
          expect(john.age).toBe 22
          expect(john.name).toBeUndefined()
          expect(john.$load).toBeDefined()
          expect(john._links).toBeDefined()
          done()
      it 'should replace the links if they are present', (done) ->
        @http.andReturn Q _links: self: href: 'http://remotehost/john'
        john = @john
        john.$load().then ->
          expect(john._links.self.href).toBe 'http://remotehost/john'
          done()
      it 'should create properties from links', (done) ->
        @http.andReturn Q _links:
          self: href: @john._links.self.href
          address: href: 'http://localhost/john/address'
        john = @john
        john.$load().then ->
          expect(john.address).toBeDefined()
          expect(john.address._links.self.href).toBe 'http://localhost/john/address'
          done()

    describe '$save', ->
      it 'should issue a PUT request', (done) ->
        http = @http
        @john.$save().then ->
          expect(http).toHaveBeenCalledWith jasmine.objectContaining
            method: 'PUT', url: 'http://localhost/john'
            data: JSON.stringify name: 'john'
            headers: { 'Content-Type': 'application/json' }
          done()

    describe '$delete', ->
      it 'should issue a DELETE request', (done) ->
        http = @http
        @john.$delete().then ->
          expect(http).toHaveBeenCalledWith jasmine.objectContaining
            method: 'DELETE', url: 'http://localhost/john'
          done()
      it 'should DELETE the loaded self link', (done) ->
        http = @http
        http.andReturn Q _links: self: href: 'http://remotehost/john'
        john = @john
        john.$load().then ->
          http.andReturn Q()
          john.$delete().then ->
            expect(http).toHaveBeenCalledWith jasmine.objectContaining
              method: 'DELETE', url: 'http://remotehost/john'
            done()

    describe '$remove', ->
      it 'should issue a DELETE request', (done) ->
        http = @http
        @john.$remove().then ->
          expect(http).toHaveBeenCalledWith jasmine.objectContaining
            method: 'DELETE', url: 'http://localhost/john'
          done()
      it 'should DELETE the original link of loaded objects', (done) ->
        http = @http
        http.andReturn Q _links: self: href: 'http://remotehost/john'
        john = @john
        john.$load().then ->
          http.reset()
          john.$remove().then ->
            expect(http).toHaveBeenCalledWith jasmine.objectContaining
              method: 'DELETE', url: 'http://localhost/john'
            done()

    describe '$set', ->
      it 'should issue a PUT request', (done) ->
        http = @http
        paul = @api.$bind "paul"
        father = @john.$bind "father"
        father.$set(paul).then ->
          expect(http).toHaveBeenCalledWith jasmine.objectContaining
            method: 'PUT'
            url: 'http://localhost/john/father'
            data: 'http://localhost/paul'
          done()

  describe 'operations on collections', ->
    beforeEach ->
      @addresses = []
      @api.$bind 'addresses', @addresses

    describe '$load', ->
      it 'should map collections', (done) ->
        addresses = @addresses
        @http.andReturn Q
          _links:
            self: href: addresses._links.self
          _embedded:
            addresses: [
                city: 'London'
                _links: self: href: "http://localhost/london"
              ,
                city: 'Paris'
            ]
        addresses.$load().then ->
          expect(addresses.length).toBe 2
          expect(addresses[0].city).toBe 'London'
          expect(addresses[1].city).toBe 'Paris'
          expect(addresses[0].$load).toBeDefined()
          expect(addresses[1].$load).toBeUndefined()
          done()

    describe '$add', ->
      it 'single item should issue POST', (done) ->
        addresses = @addresses
        http = @http
        item = city: 'New York', _links: self: href: "http://localhost/newyork"
        addresses.$add(item).then ->
          expect(http).toHaveBeenCalledWith jasmine.objectContaining
            method: 'POST', url: 'http://localhost/addresses'
            data: 'http://localhost/newyork'
          done()

      it 'items should issue POST', (done) ->
        addresses = @addresses
        http = @http
        items = [
          { city: 'New York', _links: self: href: "http://localhost/newyork" },
          { city: 'New Dehli', _links: self: href: "http://localhost/newdehli" } ]
        addresses.$add(items).then ->
          expect(http).toHaveBeenCalledWith jasmine.objectContaining
            method: 'POST', url: 'http://localhost/addresses'
            data: 'http://localhost/newyork\nhttp://localhost/newdehli'
            headers: { 'Content-Type': 'text/uri-list' }
          done()
