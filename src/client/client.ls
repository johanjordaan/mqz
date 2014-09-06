errorController = ($scope,Errors) ->
  $scope.errors = Errors

  $scope.clear = ->
    Errors.length = 0

menuController = ($scope,$location) ->
  $scope.navigate = (destination) ->
    $location.path destination

  $scope.isSelected = (destination) ->

quizController = ($scope,Api,State) ->
  $scope.question = do
    question:"???"

  $scope.answer = false

  if !State.CurrentQuestion?
    Api.getQuestion { token:"johan",sets:["JOU"] }, (data) ->
      $scope.question = data
      State.CurrentQuestion = data
      $scope.image = "background-image: url(http://mtgimage.com/set/JOU/#{data.question}-crop.jpg);"
  else
    $scope.question = State.CurrentQuestion

  $scope.submitAnswer = (index) ->
    Api.answerQuestion do
      token: "johan"
      question_id: $scope.question.id
      answer_index: index
      ,(data) ->

        if data.correct
          $scope.result = "Correct"
        else
          $scope.result = "Incorrect"

        $scope.result = $scope.result + ",the answer is #{$scope.question.options[data.correct_answer_index]}"
        $scope.answer = true

  $scope.next = ->
    Api.getQuestion { token:"johan",sets:["JOU"] }, (data) ->
      $scope.question = data
      State.CurrentQuestion = data
      $scope.image = "background-image: url(http://mtgimage.com/set/JOU/#{data.question}-crop.jpg);"
      $scope.answer = false

  $scope.showAnswer = ->
    $scope.answer

  $scope.showQuestion = ->
    !$scope.answer




settingsController = ($scope,Api) ->

statsController = ($scope,Api) ->

userController = ($scope,Api) ->


apiFactory = ($resource,ErrorHandler) ->
  do
    getQuestion: (data, cb) ->
      $resource '/api/v1/questions', null
      .save {}, data, cb, ErrorHandler

    answerQuestion: (data, cb) ->
      $resource '/api/v1/answers', null
      .save {}, data, cb, ErrorHandler

errorHandlerFactory = (Errors) ->
  (err) ->
    Errors.push err.data.message

config = ($routeProvider) ->
  $routeProvider
  .when '/home', do
    templateUrl: 'quiz.html'
    controller: 'quizController'

  .when '/user', do
    templateUrl: 'user.html'
    controller: 'userController'

  .when '/settings', do
    templateUrl: 'settings.html'
    controller: 'settingsController'

  .when '/stats', do
    templateUrl: 'stats.html'
    controller: 'statsController'

  .otherwise do
    redirectTo: '/home'


app = angular.module 'gameApp',['ngResource','ngRoute']

app.factory 'Api',['$resource','ErrorHandler',apiFactory]
app.factory 'ErrorHandler',['Errors',errorHandlerFactory]
app.value 'Errors',[]
app.value 'State',{}

app.controller 'errorController', ['$scope','Errors',errorController]
app.controller 'menuController', ['$scope','$location',menuController]

app.controller 'quizController', ['$scope','Api','State',quizController]
app.controller 'settingsController', ['$scope','Api',settingsController]
app.controller 'statsController', ['$scope','Api',statsController]
app.controller 'userController', ['$scope','Api',userController]


app.config ['$routeProvider',config]
