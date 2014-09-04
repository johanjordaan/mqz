errorController = ($scope,Errors) ->
  $scope.errors = Errors

  $scope.clear = ->
    Errors.length = 0

quizController = ($scope,Api) ->

settingsController = ($scope,Api) ->

statsController = ($scope,Api) ->


apiFactory = ($resource,ErrorHandler) ->
  do
    findMatches: (params, cb) ->
      $resource '/api/v1/matches', null
      .query params, cb, ErrorHandler


    startMatch: (params, cb) ->
      $resource '/api/v1/matches/:match_id', null
      .save params, cb, ErrorHandler


    joinMatch: (params, player, cb) ->
      $resource '/api/v1/matches/:match_id/players', null
      .save params, player, cb, ErrorHandler

    getMatchState: (params, cb) ->
      $resource '/api/v1/matches/:match_id', null
      .get params, cb, ErrorHandler

    makeMove: (params, move) ->
      new Promise (resolve,reject) ->
        $resource 'api/v1/matches/:match_id/moves', null
        .save params, move, resolve, (err)->
          ErrorHandler err
          reject err


errorHandlerFactory = (Errors) ->
  (err) ->
    Errors.push err.data.message

config = ($routeProvider) ->
  $routeProvider
  .when '/', do
    templateUrl: 'quiz.html'
    controller: 'quizController'

  .when '/settings', do
    templateUrl: 'settings.html'
    controller: 'settingsController'

  .when '/stats', do
    templateUrl: 'stats.html'
    controller: 'statsController'



  .otherwise do
    redirectTo: '/'


app = angular.module 'gameApp',['ngResource','ngRoute']

app.factory 'Api',['$resource','ErrorHandler',apiFactory]
app.factory 'ErrorHandler',['Errors',errorHandlerFactory]
app.value 'Errors',[]

app.controller 'errorController', ['$scope','Errors',errorController]
app.controller 'quizController', ['$scope','Api',quizController]
app.controller 'settingsController', ['$scope','Api',settingsController]
app.controller 'statsController', ['$scope','Api',statsController]

app.config ['$routeProvider',config]
