$ ->
  STATUS = { choose_address: 49 }
  $('#btn-choose-clothes:not(.disabled)').click (e) ->
    e.preventDefault()
    $this = $(@)
    $this.addClass('disabled')
    url = $this.prop('href')
    $.ajax url,
      type: 'PUT'
      data: { status_id: STATUS.choose_address, clothes_code: $this.data('clothes-code') }
      success: (data, textStatus, jqXHR) ->
        location.href = url
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')
