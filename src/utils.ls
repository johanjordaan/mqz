_ = require 'prelude-ls'
crypto = require 'crypto'

/**
 * @description utils module
 *
**/

generate_token = (data) ->
  nonse = new Buffer( [1 to 256] |> _.map (item) -> Math.floor 256*Math.random() )
  hash = crypto.createHash 'sha256'
  data |> _.obj-to-pairs |>  _.each (item) -> hash.update item[1]
  hash.update nonse
  token = hash.digest 'hex'

shuffle = (source) ->
    result  = source |> _.map (element) -> element
    # From the end of the list to the beginning, pick element `i`.
    for i in [0 to result.length-1]
      # Choose random element `j` to the front of `i` to swap with.
      j = Math.floor Math.random() * (i + 1)
      # Swap `j` with `i`, using destructured assignment
      [result[i], result[j]] = [result[j], result[i]]
    # Return the shuffled array.
    result


/**
 * Represents a book.
 * @constructor
 * @param {string} title - The title of the book.
 * @param {string} author - The author of the book.
 */
random_pick = (source) ->
  shuffled_list = source |> shuffle
  return shuffled_list[0]


fail = (ctx,f_name,threshold,fcb) ->
  f = ctx[f_name]
  count = 0
  ctx[f_name] = ->
    if count>=threshold
      ctx[f_name] = f
      fcb.apply this,arguments
    else
      count := count+1
      f.apply this,arguments
  null


/* istanbul ignore else */
if module?
  module.exports =
    generate_token: generate_token
    shuffle: shuffle
    random_pick: random_pick
    fail: fail
