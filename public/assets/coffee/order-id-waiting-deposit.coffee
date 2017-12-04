$ ->
  $('#btn-force-deposit').click (e) ->
    val       = $(@).data('value')
    status_id = $(@).data('status-id')
    $.ajax location.href,
      type: 'PUT'
      dataType: 'json'
      data: { status_id: status_id, force_deposit: val }
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
