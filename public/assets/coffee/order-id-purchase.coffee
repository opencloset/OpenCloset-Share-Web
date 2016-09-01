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

  from = moment().add(1, 'days').format('YYYY-MM-DD')
  to   = moment().add(5, 'days').format('YYYY-MM-DD')
  $('#from-date').val(from)
  $('#to-date').val(to)
  $('.datepicker').datepicker
    language: 'kr'
    startDate: '+1d'
    todayHighlight: true
    autoclose: true
    format: 'yyyy-mm-dd'

  $('#from-date').on 'change', ->
    from = $(@).val()
    to   = moment(from).add(4, 'days').format('YYYY-MM-DD')
    $('#to-date').val(to)
