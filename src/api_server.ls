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
ObjectID = require('mongoskin').ObjectID
db_name = "mongodb://localhost/mqz"
db = mongo.db db_name, {native_parser:true}
db.bind 'sets'
db.bind 'cards'
db.bind 'questions'
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
      db.bind 'questions'
      db.bind 'users'
    app


app.get '/api/v1/sets/', (req, res) ->
  db.sets.findItems {}, (err, sets) ->
    | err? => res.status(500).send err
    | otherwise => res.status(200).send sets

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
app.post '/api/v1/questions', (req, res) ->
  token = req.body.token
  sets = req.body.sets
  properties = req.body.properties


  if !token?
    res.status(400).send { message: "Please provide a token" }
    return

  if !sets? or sets.length == 0
    res.status(400).send { message: "Please provide at least one set" }
    return

  if !properties? or properties.length==0
    properties = ['type','color','pt','manaCost','text'] #,'imageName']

  find_with_property = (sets,total,property,exclude,cb) ->
    skip = lcg.rnd_int_between 0,total
    fltr = do
      set_code: { '$in':sets }
    fltr[property] = { '$exists': true }

    db.cards.findOne fltr, null, { limit: 1, skip: skip }, (err,card) ->
      switch
      | err? => res.status(500).send err
      | !card? => find_with_property sets, total, property, exclude, cb
      | otherwise =>
        switch card.name == exclude?.name
        | true => find_with_property sets, total, property, exclude, cb
        | otherwise => cb card

  find_fake_options = (sets,total,property,card,number,options,cb) ->
    switch number
    | options.length => cb options
    | otherwise =>
      find_with_property sets,total,property,card, (fake) ->
        option = fake[property].replace fake.name,'____'
        switch option in options
        | true => find_fake_options sets, total, property, card, number, options, cb
        | otherwise =>
          options.push option
          find_fake_options sets, total, property, card, number, options, cb

  build_question = (sets,properties,cb) ->
    db.sets.findItems { code: { '$in':sets } }, (err, dbsets) ->
      | err? => err.status(500).send err
      | otherwise =>
        total = 0
        for set in dbsets
          total += set.num_cards

        property = utils.random_pick properties
        find_with_property sets, total, property, {}, (card) ->
          answer = card[property].replace card.name,'____'
          find_fake_options sets, total, property, card, 4, [answer], (options) ->
            options  = options |> utils.shuffle
            answer_index = options |> _.find-index (option) -> option == answer
            cb do
              question: card.name
              answer_index: answer_index
              options: options
              property: property
              set_code: card.set_code
              image_name: card.imageName
              answered: false

  generate_question = (user)->
    build_question sets,properties, (question) ->
      question.user = user._id
      db.questions.save question, (err) ->
        | err? => res.status(500).send err
        | otherwise => res.status(200).send do
          id: question._id
          question: question.question
          options: question.options
          property: question.property
          image_name: question.image_name
          set_code: question.set_code

  db.users.findOne { token: token }, (err, user) ->
    | err? => res.status(500).send err
    | !user? =>
      user = { token: token }
      db.users.save user, (err) ->
        | err? => res.status(500).send err
        | otherwise => generate_question user
    | otherwise => generate_question user



app.post '/api/v1/answers', (req, res) ->
  token = req.body.token
  question_id = req.body.question_id
  answer_index = req.body.answer_index


  if !token?
    res.status(400).send { message: "Please provide a token" }
    return

  if !question_id?
    res.status(400).send { message: "Please provide a question id" }
    return

  if !answer_index?
    res.status(400).send { message: "Please provide an answer index" }
    return

  answer_index = Number answer_index

  db.users.findOne { token: token }, (err, user) ->
    | err? => res.status(500).send err
    | !user? => res.status(400).send { message: "Please provide a valid token" }
    | otherwise =>
      db.questions.findOne { _id: new ObjectID(question_id), user: new ObjectID(user._id), answered: false }, (err, question) ->
        | err? => res.status(500).send err
        | !question? => res.status(400).send { message: "Please provide a valid question id"}
        | otherwise =>
          correct = question.answer_index == answer_index
          result = if correct then "correct" else "incorrect"
          db.users.update user,{'$inc':{"sets.#{question.set_code}.#{question.question}.#{question.property}.#{result}":1}}, (err, wr) ->
            | err? => res.status(500).send err
            | otherwise =>
              db.questions.update question, { '$set': { answered: true, user_answer_index: answer_index } }, (err, wr) ->
                | err? => res.status(500).send err
                | otherwise =>
                  res.status(200).send { correct: correct ,correct_answer_index: question.answer_index }
