fs = require 'fs'
async = require 'async'
_ = require 'prelude-ls'

express = require 'express'
bodyParser = require 'body-parser'

utils = require './utils'
lcg = require 'lcg-rnd'

app = express()

# Configure express
app.use bodyParser.json()
app.use '/',express.static(__dirname + '/client')

server = (require 'http').createServer app

LISTEN_PORT = 4000

######## DB Initialisation
mongo = require 'mongoskin'
db_name = "mongodb://localhost/mqz"
db = mongo.db db_name, {native_parser:true}
db.bind 'sets'
db.bind 'cards'
db.bind 'users'


/* istanbul ignore if */
if require.main == module
  server.listen LISTEN_PORT, ->
     console.log "mqz API Server - Listening on port #{LISTEN_PORT}"
else
  module.exports = (test_db) ->
    /* istanbul ignore else */
    if test_db?
      db := test_db
      db.bind 'sets'
      db.bind 'cards'
      db.bind 'users'
    app


# Imports a set removing all in the set
app.post '/api/v1/sets/:set_code', (req, res) ->
  set_code = req.param 'set_code'

  db.cards.remove { set_code:set_code },(err,writeResult) ->
    | err? => res.status(500).send err
    | otherwise =>
      file = "./sets/#{set_code}.json";

      fs.readFile file, 'utf8', (err, data) ->
        | err? => res.status(500).send err
        | otherwise =>
          set = JSON.parse(data)
          inserts = []
          for card in set.cards
            x = (card) ->
              inserts.push (cb) ->
                # Customisations
                card.set_code = set_code
                if card.power? then card.pt = "#{card.power}/#{card.toughness}"
                if card.colors? then card.color = _.join " ",card.colors
                db.cards.save card,(err) ->
                  | err? => cb(null,err)
                  | otherwise => cb(null,true)
            x card
          async.parallel inserts, (err,results) ->

            db.sets.remove {code:set_code}, (err,writeResult) ->
              | err? => res.status(500).send err
              | otherwise =>
                db.sets.save { name:set.name, code:set.code, num_cards:set.cards.length }, (err,saved_set) ->
                  | err? => res.status(500).send err
                  | otherwise => res.status(200).send saved_set

# Returns/creates a new question based on the set or sets requested
# input : token - identifies the user
# input : sets - array of sets to select questions from. if empty or null then all sets
# input : properties - array of properties to test default = ['types','subtypes','colors','manaCost','text']

find_with_property = (fltr,total,property,exclude,cb) ->
  skip = lcg.rnd_int_between 0,total
  fltr2 = do
    set_code: fltr.set_code
  fltr2[property] = { '$exists': true }

  db.cards.findOne fltr2, null, { limit: 1, skip: skip }, (err,card) ->
    | err? => res.status(500).send err
    | !card? => find_with_property fltr2, total, property, exclude, cb
    | otherwise =>
      switch card.name == exclude?.name
      | true => find_with_property fltr2, total, property, exclude, cb
      | otherwise => cb card

find_fake_options = (fltr,total,property,card,number,options,cb) ->
  switch number
  | options.length => cb options
  | otherwise =>
    find_with_property fltr,total,property,card, (fake) ->
      option = fake[property].replace fake.name,"___"
      switch option in options
      | true => find_fake_options fltr, total, property, card, number, options, cb
      | otherwise =>
        options.push option
        find_fake_options fltr, total, property, card, number, options, cb

build_question = (sets,properties,cb) ->
  fltr = {}
  if sets? then fltr.set_code = { '$in': sets }

  db.sets.findItems fltr, (err, sets) ->
    | err? => err.status(500).send err
    | otherwise =>
      total = 0
      for set in sets
        total += set.num_cards

      property = utils.random_pick properties
      find_with_property fltr, total, property, {}, (card) ->
        find_fake_options fltr, total, property, card, 4, [card[property]], (options) ->
          cb do
            question: card.name
            #answer: card[property].replace card.name,"___"
            options: utils.shuffle options
            property: property
            set_code: card.set_code
            image_name: card.imageName


init_user = (token,sets) ->
  fltr = {}
  if sets? then fltr.set_code = { '$in': sets }

  db.users.findOne { token: token }, (err, user) ->


  stats = {}
  db.cards.findItems fltr, (err, cards) ->
    cards_by_set = cards |> _.group (card) -> card.set_code
    sets = cards_by_set |> _.keys
    for set in sets
      stats[set] = {}
      for card in cards_by_set[set]
        stats[set][card.name] = { correct: 0, incorrect: 0 }

    user = do
      token: token

    db.user.save




app.post '/api/v1/questions', (req, res) ->
  token = req.body.token
  sets = req.body.sets
  properties = req.body.properties

  if !properties? or properties.length==0 then properties = ['type','color','pt','manaCost','text','imageName']

  build_question sets,properties, (question) ->
    res.status(200).send question


app.post '/api/v1/answers', (req, res) ->
  token = req.body.token
  user_answer = req.body.answer
  question = req.body.question
  set_code = req.body.set_code
  property = req.body.property

  db.cards.findOne { set_code:set_code name: question }, (err, card) ->
    | err? => res.status(500).send err
    | !card? => res.status(400).send { message: 'Invalid question' }
    | otherwise =>
      answer = card[property].replace card.name,"___"
      result = if answer == user_answer then "correct" else "incorrect"

      db.users.findOne { token: token }, (err, user) ->
        | err? => res.status(500).send err
        | !user? =>
          user = { token: token }
          user.sets = {}
          user.sets[set_code] = {}
          user.sets[set_code][question] = {}
          user.sets[set_code][question][type] = {}
          user.sets[set_code][question][type][result] = 1
          db.users.save user, (err) ->
            | err? => res.status(500).send err
            | otherwise => res.status(200).send ''
        | otherwise =>
          db.users.update {user},{'$inc':"sets.#{set_code}.#{question}.#{type}.#{result}:1"}, (err) ->
            | err? => res.status(500).send err
            | otherwise => res.status(200).send ''
