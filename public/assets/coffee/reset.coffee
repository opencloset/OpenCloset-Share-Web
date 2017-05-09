$ ->
  $('#btn-find-email').click (e) ->
    e.preventDefault()
    $('#form-reset').toggleClass('hidden')
    $('#form-find-email').toggleClass('hidden')
