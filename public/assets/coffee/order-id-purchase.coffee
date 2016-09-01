$.fn.editable.defaults.ajaxOptions =
  type: "PUT"
  dataType: 'json'

$ ->
  Handlebars.registerHelper 'detachZero', (opts) ->
    opts.fn(this).replace(/^0/, '')

  order_id = location.pathname.split('/')[2]
  $.ajax "/clothes/recommend?order_id=#{order_id}",
    type: 'GET'
    dataType: 'json'
    success: (data, textStatus, jqXHR) ->
      template = JST['recommend']
      html     = template(data)
      $('#recommend-clothes').append(html)
    error: (jqXHR, textStatus, errorThrown) ->
    complete: (jqXHR, textStatus) ->

  $('#staff-list').editable
    params: (params) ->
      params[params.name] = params.value
      params
