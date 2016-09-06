$.fn.editable.defaults.ajaxOptions =
  type: "PUT"
  dataType: 'json'

$ ->
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

  $('#form-clothes-code').submit (e) ->
    e.preventDefault()
    $this  = $(@)
    $input = $this.find('input[name="code"]')
    code   = $input.val().toUpperCase()
    url    = $this.prop('action').replace(/xxx/, code)

    $.ajax url,
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        data.category   = OpenCloset.category[data.category]
        data.status     = OpenCloset.status[data.status_id]
        data.labelColor = OpenCloset.status.color[data.status_id]
        data.disabled   = switch data.status_id
          when "2", "3", "7", "8" then true
          else false
        template = JST['clothes-item']
        html     = template(data)
        $('#table-clothes tbody').append(html)
      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ title:textStatus, message: jqXHR.responseJSON.error })
      complete: (jqXHR, textStatus) ->
        $input.val('')

  $('#btn-update-order:not(.disabled)').click (e) ->
    $this = $(@)
    $this.addClass('disabled')
    url = $('#form-update-order').prop('action')
    $.ajax url,
      type: 'PUT'
      data: $('#form-update-order').serialize()
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')
